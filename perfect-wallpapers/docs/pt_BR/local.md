# Guia do Provedor de Pastas Locais

O provedor **Local** no Perfect Wallpapers permite navegar, pesquisar e aplicar papéis de parede a partir da sua própria coleção offline de fotos e vídeos direto no painel do plugin.

---

## 1. Recursos & Formatos Suportados

- **Varredura Recursiva**: Percorre automaticamente as pastas configuradas buscando arquivos suportados.
- **Abas de Mídia**:
  - **Images**: Navegação rápida por `.jpg`, `.jpeg`, `.png`, `.webp`, `.bmp`, `.svg` e `.avif`.
  - **Videos**: Navegação por `.mp4`, `.webm`, `.mkv` e `.mov`.
- **Busca Instantânea**: Digite no campo de pesquisa para filtrar arquivos imediatamente por nome do arquivo, pasta ou caminho relativo.
- **Paginação Fluida**: Gerencia coleções volumosas (centenas ou milhares de arquivos) com paginação ágil, sem travamentos na interface.
- **Aplicação Direta**: Mídias locais são aplicadas diretamente no local de origem, sem cópias desnecessárias ou consumo extra de disco.

---

## 2. Configurando Pastas Locais

Por padrão, o plugin busca em `~/Pictures` e `~/Pictures/Wallpapers` caso nenhuma pasta específica seja informada.

Para configurar suas próprias pastas:
1. Abra o painel do plugin e clique no botão **Manage folders** (ou acerte em **Settings → Plugins → Perfect Wallpapers**).
2. Localize a configuração **Local directories** (`local_directories`).
3. Adicione um caminho absoluto por linha (ex.: `/home/usuario/Imagens/Wallpapers` ou `/mnt/dados/Fotos`).
4. Ao reabrir ou atualizar a aba Local, as pastas são indexadas na hora.

---

## 3. Motores de Execução

- **Imagens Estáticas**:
  Aplicadas diretamente pelo renderizador nativo do Noctalia. As paletas de tema e cores de destaque são recalculadas instantaneamente.
- **Vídeos**:
  Reproduzidos suavemente como fundo de tela pelo `mpvpaper`. Suporta áudio silenciado (`mute_video`), decodificação acelerada por hardware (`hardware_decode`) e limites de taxa de quadros (`video_fps`).
