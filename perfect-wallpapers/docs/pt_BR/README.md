# Perfect Wallpapers

**Perfect Wallpapers** é a sua central unificada de controle para papéis de parede em imagem, vídeo e cenas interativas no Noctalia. O plugin conta com integração completa com a **API do Wallhaven** para imagens estáticas de alta resolução, com a **API do Pixabay** para fotos e vídeos em loop de tirar o fôlego, com pastas locais para coleções pessoais e com o **Wallpaper Engine (Steam Workshop)** para cenas interativas e animadas.

Este plugin foi concebido e arquitetado para unificar todos os fluxos de trabalho de wallpapers em uma única interface coesa, eliminando a necessidade de buscar, instalar e configurar múltiplos plugins fragmentados de fontes diferentes. Desenvolvido com foco absoluto em desempenho e uso consciente de recursos de hardware:
- **Encerramento automático de backends & máxima eficiência:** Ao trocar de provedor — por exemplo, ao sair do Wallpaper Engine (que executa o `linux-wallpaperengine`) e aplicar um papel de parede do Wallhaven, Pixabay ou pastas locais — o processo do `linux-wallpaperengine` é imediatamente finalizado. Motores dinâmicos nunca ficam rodando em segundo plano sem necessidade, liberando 100% dos shaders da GPU e ciclos de CPU para seus aplicativos e jogos.
- **Cache de sessão em RAM:** Páginas de busca, consultas e miniaturas de preview residem na memória RAM (`tmpfs`) estritamente enquanto a aba do hub estiver aberta, descartando estruturas de memória e excluindo o cache temporário imediatamente ao fechar.
- **Cache inteligente baseado em parâmetros e busca:** As pesquisas, estados de paginação e miniaturas de preview são indexados exatamente pelos seus parâmetros (tags, proporção de aspecto, pureza, resolução, ordenação). Isso evita que o seu limite máximo de requisições de API seja consumido apenas porque você alternou entre abas ou repetiu pesquisas recentes.
- **Expiração automática de sessão:** O cache de sessão expira sozinho a cada 24 horas e é limpo na inicialização do serviço, garantindo que nenhum acúmulo de arquivos ocupe o seu disco mesmo em sessões prolongadas do computador.

---

## Plugin

| Campo | Valor |
| --- | --- |
| ID | `perfect/perfect-wallpapers` |
| Entradas | Widget da barra: `widget`; painel: `hub`; atalho: `shortcut`; serviço: `service`; widget de desktop: `desktop` |

---

## Provedores Suportados (Visão Geral)

Para instruções detalhadas de configuração, resolução de dependências, obtenção de chaves de API e ajustes avançados, consulte os guias dedicados:

| Provedor | Tipos de Mídia | Chave de API / Requisitos | Documentação |
| :--- | :--- | :--- | :--- |
| **Daily Wallpaper** | Arquivo diário 4K/UHD (Bing) & NASA APOD | Nenhuma | Integrado |
| **Wallhaven** | Imagens estáticas em altíssima resolução & arte anime | Opcional (chave gratuita para NSFW e limites maiores) | [Guia do Wallhaven](wallhaven.md) |
| **Pixabay** | Fotos, ilustrações & vídeos em loop de alta fidelidade | Obrigatória (chave pessoal gratuita) | [Guia do Pixabay](pixabay.md) |
| **Wallpaper Engine** | Cenas 2D/3D interativas, loops de vídeo & páginas web | `linux-wallpaperengine` + Steam Workshop | [Guia do Wallpaper Engine](wallpaper-engine.md) |
| **Pastas Locais** | Imagens & vídeos da sua coleção pessoal offline | Nenhuma | [Guia do Provedor Local](local.md) |

---

## Requisitos

O plugin requer o Noctalia com nível de API de plugin ≥ 28. Ferramentas externas e tokens de API dependem dos provedores utilizados:

- `mpvpaper` e `mpv`: necessários para reprodução de vídeos.
- `linux-wallpaperengine`: necessário para cenas interativas do Steam Workshop.
- `setsid` e `pkill`: utilitários padrão do sistema para gerenciamento de processos em segundo plano.
- Pixabay: token de API pessoal gratuito (veja o [Guia do Pixabay](pixabay.md)).
- Wallhaven: token de API pessoal opcional (veja o [Guia do Wallhaven](wallhaven.md)).

---

## Uso

Instruções para acessar cada entrada do usuário:

### 1. Widget da Barra
Adicione a entrada `widget` à sua barra no Noctalia (**Settings → Bar → Widgets**). Ao clicar no widget, o painel `hub` é aberto/fechado. O widget reflete dinamicamente o status (o ícone muda para `movie` quando um vídeo ou Wallpaper Engine estiver tocando).

### 2. Atalho do Painel de Controle (Control Center)
Adicione a entrada `shortcut` ao seu Control Center (**Settings → Control Center → Shortcuts**). O atalho sinaliza quando há um wallpaper ativo e abre o `hub` com um clique.

### 3. Widget de Desktop
Adicione a entrada `desktop` à sua área de trabalho (**Settings → Desktop → Widgets**). O widget exibe na sua tela o título, créditos fotográficos/científicos, data e resumo da explicação do Wallpaper Diário ativo.

### 4. Linha de Comando & IPC
Abra o painel ou controle o serviço em segundo plano via IPC:

```sh
# Abrir / fechar o painel do hub
noctalia msg panel-toggle perfect/perfect-wallpapers:hub

# Alternar provedor diretamente via IPC
noctalia msg plugin perfect/perfect-wallpapers:hub all daily
noctalia msg plugin perfect/perfect-wallpapers:hub all wallhaven
noctalia msg plugin perfect/perfect-wallpapers:hub all pixabay
noctalia msg plugin perfect/perfect-wallpapers:hub all wallpaperengine
noctalia msg plugin perfect/perfect-wallpapers:hub all local

# Consultar o status ativo
noctalia msg plugin perfect/perfect-wallpapers:service all status

# Rotacionar / aplicar o papel de parede diário de hoje
noctalia msg plugin perfect/perfect-wallpapers:service all apply-daily

# Parar motores ativos de vídeo ou Wallpaper Engine
noctalia msg plugin perfect/perfect-wallpapers:service all stop

# Limpar o cache de sessão manualmente
noctalia msg plugin perfect/perfect-wallpapers:service all clear-cache
```

---

## Configurações

Configure as opções em **Settings → Plugins → Perfect Wallpapers** ou no arquivo `config.toml`:

| Configuração | Tipo | Padrão | Descrição |
| :--- | :--- | :--- | :--- |
| `default_provider` | `select` | `pixabay` | Provedor inicial ao abrir o hub (`daily`, `local`, `pixabay`, `wallhaven`, `wallpaperengine`). |
| `daily_subsource` | `select` | `bing` | Fonte padrão para o Wallpaper Diário (`bing`, `nasa`). |
| `daily_auto_rotate` | `bool` | `false` | Busca e aplica automaticamente a imagem do dia quando disponível. |
| `daily_locale` | `string` | `""` | Código de idioma/região para a galeria do Bing (ex: `pt-BR`, `en-US`). |
| `copy_to_wallpaper_dir` | `bool` | `false` | Salva uma cópia dos papéis de parede diários e locais aplicados na sua pasta pessoal. |
| `download_dir` | `folder` | `""` | Pasta padrão para download de wallpapers (vazio = `~/Pictures/Wallpapers/perfect-wallpapers`). |
| `local_directories` | `string_list` | `[]` | Lista de pastas locais varridas em busca de imagens e vídeos. |
| `wallpaperengine_dir` | `folder` | `""` | Caminho customizado da pasta do Workshop Steam `431960` se estiver fora dos locais padrão. |
| `pixabay_api_key` | `string` | `""` | Token da API gratuita do Pixabay. |
| `pixabay_safesearch` | `bool` | `true` | Restringe resultados do Pixabay a conteúdos adequados para todas as idades. |
| `pixabay_video_quality` | `select` | `large` | Resolução preferencial de streaming de vídeo (`large`, `medium`, `small`, `tiny`). |
| `wallhaven_api_key` | `string` | `""` | Token opcional do Wallhaven para limites maiores e conteúdo NSFW. |
| `wallhaven_purity_sfw` | `bool` | `true` | Inclui wallpapers seguros (SFW) do Wallhaven. |
| `wallhaven_purity_sketchy` | `bool` | `false` | Inclui wallpapers artísticos/sugestivos do Wallhaven. |
| `wallhaven_purity_nsfw` | `bool` | `false` | Inclui wallpapers adultos (requer chave de API do Wallhaven). |
| `video_fps` | `int` | `30` | Limite máximo de FPS para vídeo e Wallpaper Engine (0 = sem limite). |
| `video_scale` | `select` | `panscan` | Modo de escala para mpvpaper (`panscan`, `fit`, `stretch`). |
| `pause_on_battery` | `bool` | `true` | Pausa animações em segundo plano quando estiver usando a bateria do notebook. |
| `hardware_decode` | `bool` | `true` | Habilita aceleração por hardware da GPU na decodificação de vídeos. |
| `mute_video` | `bool` | `true` | Silencia automaticamente o áudio de papéis de parede e vídeos. |
| `stop_foreign_backends` | `bool` | `true` | Encerra daemons concorrentes (`mpvpaper`, `swww-daemon`, `awww-daemon`) ao aplicar. |

---

## English Documentation

For the original English documentation, see [docs/en_US/README.md](../en_US/README.md).
