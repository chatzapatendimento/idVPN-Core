# MEMÓRIA DO PROJETO: idVPN-Core
# Iniciado em: 2025-07-07

## REGRAS DO PROJETO (devem ser SEMPRE respeitadas)
1. A memória do projeto deve ser revisada antes de qualquer nova execução.
2. Toda ação, comando, decisão ou alteração de estrutura deve ser documentada aqui.
3. Sempre testar localmente antes de qualquer execução real.
4. Estrutura modular do projeto deve ser mantida atualizada com caminhos reais.
5. O Gemini CLI nunca deve esquecer essas regras, mesmo entre sessões.
6. Sugestões técnicas de melhoria são obrigatórias.
7. Toda decisão deve conter data, motivação e impacto técnico.
8. Toda vez que uma nova pasta, arquivo, ou script for criado, ele deve constar aqui.
9. Toda sessão iniciada deve começar com a revisão deste arquivo.
10. A memória deve ser atualizada ao finalizar qualquer etapa ou antes de solicitar um teste ao usuário.

---
## ESTRUTURA MODULAR DO PROJETO (Real e Verificada)
idVPN-Core/
├── .git/ # Repositório Git
├── .gitignore # Arquivos ignorados pelo Git
├── memory.md # Esta memória
├── backups/ # Backups criptografados dos perfis e configs
├��─ docs/ # Documentação geral do projeto
├── logs/ # Logs e debugs do sistema
├── profiles/ # Perfis OVPN de clientes gerados
├── sandbox/ # Ambiente de testes para perfis e conexões
├── scripts/
│   ├── generate_client.sh # Script para criar perfis de cliente
│   └── backup.sh # Script para realizar backups
└── web-panel/
    ├── app.py
    ├── static/
    │   └── style.css
    └── templates/
        ├── index.html
        └── revoke_confirm.html


---
## INFORMAÇÕES GERAIS DO PROJETO
- **Nome:** `idVPN-Core`
- **Servidor:** Raspberry Pi 3B rodando Raspberry Pi OS Lite 64-bit
- **Tipo de VPN:** OpenVPN (obrigatório por compatibilidade com equipamento idFace Control iD)
- **Domínio dinâmico configurado:** `pivpnaraponto.ddns.net`
- **Repositório Git:** `https://github.com/chatzapatendimento/idVPN-Core.git`
- **Objetivo:** Comunicação segura entre o PC do administrador e os equipamentos do cliente (modelo idFace da Control iD)
- **Topologia:** [PC ADMIN] ⇄ [SERVIDOR VPN (Pi)] ⇄ [EQUIPAMENTO CLIENTE]

---
## MODO SANDBOX (TESTE)
- Perfis OVPN de simulação devem ser usados para validar o painel web, sistema de geração e detecção da IA sem afetar clientes reais.
- Perfis de teste devem ser gerados no diretório `sandbox/`.

---
## LOG DE DECISÕES E ALTERAÇÕES
- **2025-07-07:**
  - **Ação:** Início do projeto, criação da estrutura de diretórios, script `generate_client.sh`, e base do painel web com Flask (listagem, geração, download).
  - **Decisão:** Documentado no log anterior.
  - **Impacto:** Base funcional do projeto estabelecida.
- **2025-07-08:**
  - **Ação:** Implementação da listagem de status e revogação de clientes no painel web.
  - **Decisão:** A rota principal foi alterada para usar `pivpn list` e exibir o status (Valid/Revoked). Foi criada a rota `/revoke` com uma página de confirmação (`revoke_confirm.html`) para revogar perfis de forma segura.
  - **Impacto:** O painel agora é uma ferramenta de gerenciamento mais completa.
- **2025-07-08:**
  - **Ação:** Criação e teste do script de backup.
  - **Decisão:** Desenvolvido o script `scripts/backup.sh` para criar arquivos `.tar.gz` das configurações críticas.
  - **Impacto:** Adiciona uma camada de segurança e recuperação de desastres ao projeto.
- **2025-07-08:**
  - **Ação:** Refatoração e correção do script `generate_client.sh`.
  - **Decisão:** O script foi melhorado com validação de entrada e ajuste de permissões.
  - **Impacto:** O script agora é mais robusto, seguro e confiável.
- **2025-07-08:**
  - **Ação:** Implementação de funcionalidades avançadas no painel web (IP do cliente, geração e download de pares).
  - **Decisão:** As rotas e templates foram atualizados para suportar a geração e o download de pares de clientes, além de exibir o IP de cada um.
  - **Impacto:** O painel atende a todos os requisitos do fluxo de trabalho do usuário.
- **2025-07-08:**
  - **Ação:** Refatoração da visualização da lista de clientes.
  - **Decisão:** A rota `index` foi reescrita para agrupar clientes em pares, melhorando a clareza da interface.
  - **Impacto:** A usabilidade do painel foi significativamente melhorada.
- **2025-07-14:**
  - **Ação:** Configuração de um sistema de backup completo e automatizado usando Git e GitHub Releases.
  - **Decisão:** O código-fonte foi versionado em um repositório Git, enquanto o script `backup.sh` foi modificado para criar um arquivo `.tar.gz` seguro e enviá-lo para o GitHub Releases. Um `cron job` foi agendado para automatizar a tarefa diariamente. Esta abordagem híbrida protege os dados sensíveis de serem expostos no histórico do Git.
  - **Impacto:** O projeto agora tem um sistema de backup off-site robusto, automatizado e seguro. A capacidade de recuperação de desastres foi estabelecida e o procedimento de restauração foi documentado.

---
*Última atualização: 2025-07-14*
