Resumo: Ferramenta de auditoria e sincronização de integridade de arquivos para ambientes de rede segmentados.

Cenário de Uso: A ferramenta foi projetada para cenários onde há isolamento de rede entre a origem e o destino:

Máquina A (Origem/Baseline): Detém os arquivos padrão, mas não possui conectividade com a Máquina B.

Máquina B (Destino/Terminal): Máquina remota que precisa ser validada, sem conectividade com a Máquina A.


Máquina C (Orquestrador): Possui acesso a ambas e executa o script.

Fluxo de Trabalho:

Geração de Baseline: A Máquina C conecta-se à Máquina A, copia os diretórios críticos e gera uma tabela de hashes (SHA256) com os caminhos relativos.


Auditoria Remota: A Máquina C conecta-se à Máquina B, calcula os hashes dos arquivos equivalentes e gera um relatório de divergências.

Reparo Automatizado (Drift Correction): Caso arquivos na Máquina B estejam ausentes ou corrompidos (hash divergente), o script utiliza a baseline da Máquina A para restaurar a integridade no destino.
