# app.py
# Ponto de entrada para o painel administrativo idVPN-Core.
#
# DATA: 2025-07-07
# CRIADO POR: Gemini CLI

from flask import Flask, render_template, request, redirect, url_for, flash, send_from_directory, send_file
import subprocess
import os
import io
import subprocess
import os

# Inicialização do aplicativo Flask
app = Flask(__name__)
# Chave secreta para usar o sistema de mensagens 'flash' do Flask.
# Em um ambiente de produção, isso deve ser uma string longa e aleatória.
app.secret_key = 'super-secret-key-change-in-production'

# Define o caminho absoluto para o diretório do projeto
PROJECT_ROOT = '/home/pi/idVPN-Core'
PROFILES_DIR = os.path.join(PROJECT_ROOT, 'profiles')


@app.route('/')
def index():
    """
    Renderiza a página principal para gerar novos clientes.
    """
    return render_template('generate.html')

@app.route('/clients')
def list_clients():
    """
    Renderiza a página que lista todos os clientes, agrupados e com status.
    """
    clients_raw = {}
    ccd_dir = '/etc/openvpn/ccd'
    
    try:
        # 1. Coleta todos os clientes e seus dados de certificado
        result_list = subprocess.run(['pivpn', 'list'], capture_output=True, text=True, check=True)
        lines_list = result_list.stdout.strip().split('\n')
        if len(lines_list) > 2:
            for line in lines_list[2:]:
                parts = line.split()
                if len(parts) >= 3:
                    name = parts[1]
                    clients_raw[name] = {'name': name, 'status': parts[0], 'ip': 'N/A', 'online': False}

        # 2. Coleta clientes online a partir do arquivo de status do OpenVPN (CORRETO)
        online_clients = set()
        status_log_path = '/var/log/openvpn/openvpn-status.log'
        try:
            with open(status_log_path, 'r') as f:
                for line in f:
                    # A linha de um cliente conectado começa com 'CLIENT_LIST' mas não é a linha do cabeçalho
                    if line.startswith('CLIENT_LIST') and not line.startswith('CLIENT_LIST,Common Name'):
                        parts = line.strip().split('\t') # O separador é TAB
                        if len(parts) > 1:
                            online_clients.add(parts[1]) # O nome é a segunda coluna (índice 1)
        except IOError:
            pass # Falha silenciosamente se não puder ler o arquivo

        # 3. Coleta IPs (RESTAURADO) e atualiza status online
        for name, client_data in clients_raw.items():
            if name in online_clients:
                client_data['online'] = True
            
            ccd_file_path = os.path.join(ccd_dir, name)
            if os.path.exists(ccd_file_path):
                try:
                    with open(ccd_file_path, 'r') as f:
                        ip_parts = f.read().split()
                        if len(ip_parts) > 1:
                            client_data['ip'] = ip_parts[1]
                except IOError:
                    client_data['ip'] = 'Erro de Leitura'

    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        flash('Erro ao executar um comando para obter dados dos clientes.', 'error')
    except Exception as e:
        flash(f'Um erro inesperado ocorreu: {e}', 'error')

    # 4. Processa a lista para separar pares e únicos, filtrando apenas clientes 'Valid'
    pairs = []
    singles = []
    processed_pairs = set()
    
    # Filtra apenas clientes com status 'Valid'
    valid_clients_raw = {name: data for name, data in clients_raw.items() if data['status'] == 'Valid'}
    sorted_client_names = sorted(valid_clients_raw.keys())

    for name in sorted_client_names:
        if name in processed_pairs:
            continue
        found_pair = False
        if name.endswith('-admin'):
            base_name = name[:-6]
            peer_name = f"{base_name}-cliente"
            if peer_name in valid_clients_raw:
                pairs.append({'base_name': base_name, 'clients': [valid_clients_raw[name], valid_clients_raw[peer_name]]})
                processed_pairs.add(name)
                processed_pairs.add(peer_name)
                found_pair = True
        elif name.endswith('-A'):
            base_name = name[:-2]
            peer_name = f"{base_name}-B"
            if peer_name in valid_clients_raw:
                pairs.append({'base_name': base_name, 'clients': [valid_clients_raw[name], valid_clients_raw[peer_name]]})
                processed_pairs.add(name)
                processed_pairs.add(peer_name)
                found_pair = True
        if not found_pair:
            # Apenas adiciona como único se não for a outra metade de um par já processado
            if not (name.endswith('-cliente') and f"{name[:-8]}-admin" in valid_clients_raw) and \
               not (name.endswith('-B') and f"{name[:-2]}-A" in valid_clients_raw):
                singles.append(valid_clients_raw[name])

    return render_template('clients.html', pairs=pairs, singles=singles)

@app.route('/download/<path:filename>')
def download_file(filename):
    """
    Fornece o download de um perfil de cliente específico.
    """
    return send_from_directory(PROFILES_DIR, filename, as_attachment=True)




@app.route('/generate', methods=['POST'])
def generate_client():
    """
    Rota para gerar um novo perfil de cliente VPN.
    Recebe o nome do cliente via formulário POST.
    """
    client_name = request.form.get('client_name')
    if not client_name or not client_name.strip():
        flash('O nome do cliente não pode estar vazio.', 'error')
        return redirect(url_for('index'))

    # Sanitiza o nome do cliente para evitar injeção de comandos
    # Permite apenas letras, números, hífens e underscores.
    sanitized_name = "".join(c for c in client_name if c.isalnum() or c in ('-', '_'))

    if sanitized_name != client_name:
        flash(f'Nome de cliente inválido. Use apenas letras, números, "-" e "_".', 'error')
        return redirect(url_for('index'))
    
    script_path = os.path.join(PROJECT_ROOT, 'scripts', 'generate_client.sh')
    
    try:
        # Executa o script com sudo. O Flask não deve rodar como root,
        # então o sudo é necessário para que o script possa chamar o pivpn.
        # É crucial configurar o sudoers para não pedir senha para este comando específico.
        command = ['sudo', script_path, sanitized_name]
        
        # O diretório de trabalho é importante para o script encontrar outros recursos se necessário.
        result = subprocess.run(command, cwd=PROJECT_ROOT, capture_output=True, text=True, check=True)
        
        flash(f'Perfil para "{sanitized_name}" gerado com sucesso!', 'success')

    except subprocess.CalledProcessError as e:
        flash(f'Erro ao gerar o perfil para "{sanitized_name}".', 'error')
        flash(f'Erro: {e.stderr}', 'error')
    except FileNotFoundError:
        flash('Erro: O script de geração não foi encontrado.', 'error')

    return redirect(url_for('list_clients'))


@app.route('/generate_pair', methods=['POST'])
def generate_pair():
    """
    Rota para gerar um par de perfis de cliente (A e B).
    """
    base_name = request.form.get('base_name')
    if not base_name or not base_name.strip():
        flash('O nome base não pode estar vazio.', 'error')
        return redirect(url_for('index'))

    # Sanitiza o nome base
    sanitized_base_name = "".join(c for c in base_name if c.isalnum() or c in ('-', '_'))
    if sanitized_base_name != base_name:
        flash(f'Nome base inválido. Use apenas letras, números, "-" e "_".', 'error')
        return redirect(url_for('index'))

    clients_to_generate = [f"{sanitized_base_name}-admin", f"{sanitized_base_name}-cliente"]
    success = True

    for client_name in clients_to_generate:
        script_path = os.path.join(PROJECT_ROOT, 'scripts', 'generate_client.sh')
        try:
            command = ['sudo', script_path, client_name]
            subprocess.run(command, cwd=PROJECT_ROOT, capture_output=True, text=True, check=True)
            flash(f'Perfil para "{client_name}" gerado com sucesso!', 'success')
        except subprocess.CalledProcessError as e:
            flash(f'Erro ao gerar o perfil para "{client_name}".', 'error')
            flash(f'Erro: {e.stderr}', 'error')
            success = False
        except FileNotFoundError:
            flash(f'Erro: O script de geração não foi encontrado para "{client_name}".', 'error')
            success = False
    
    return redirect(url_for('list_clients'))


@app.route('/revoke/<client_name>', methods=['GET', 'POST'])
def revoke_client(client_name):
    """
    Rota para revogar um perfil de cliente.
    GET: Mostra uma página de confirmação.
    POST: Executa a revogação.
    """
    if request.method == 'POST':
        try:
            # O comando 'pivpn -r' é interativo e pede confirmação.
            # Usamos 'yes' para automatizar a confirmação.
            command = f"yes | sudo pivpn -r {client_name}"
            
            result = subprocess.run(command, shell=True, capture_output=True, text=True, check=True)
            
            flash(f'Perfil para "{client_name}" revogado com sucesso!', 'success')

        except subprocess.CalledProcessError as e:
            flash(f'Erro ao revogar o perfil para "{client_name}".', 'error')
            flash(f'Erro: {e.stderr}', 'error')
        
        return redirect(url_for('list_clients'))

    # Para o método GET, renderiza a página de confirmação.
    return render_template('revoke_confirm.html', client_name=client_name)


if __name__ == '__main__':
    # Executa o servidor em modo de debug, acessível na rede local.
    # ATENÇÃO: Mudar para um servidor de produção (como Gunicorn) em ambiente real.
    app.run(host='0.0.0.0', port=5000, debug=True)
