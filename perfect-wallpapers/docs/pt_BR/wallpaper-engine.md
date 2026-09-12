# Guia do Provedor Wallpaper Engine (Steam Workshop)

O [Wallpaper Engine](https://store.steampowered.com/app/431960/Wallpaper_Engine/) no Steam é a plataforma de referência para papéis de parede animados, interativos e em 3D.

O Perfect Wallpapers traz suporte nativo ao Wallpaper Engine para o Noctalia e compositores Wayland (como o Umbriel), permitindo navegar, buscar e aplicar os papéis de parede do Steam Workshop inscritos em sua conta Steam, com extração automática de cores e controles de economia de energia.

---

## 1. Tipos de Papéis de Parede Suportados

O Perfect Wallpapers analisa os itens da sua pasta do Workshop e os cataloga automaticamente em:

1. **Scene**: Cenas 2D e 3D renderizadas em tempo real com shaders OpenGL/Vulkan.
2. **Video**: Loops de vídeo animados pré-renderizados em alta resolução.
3. **Web**: Aplicações web interativas em HTML5, WebGL e JavaScript.

O painel oferece um seletor de tipos (**All**, **Scene**, **Video**, **Web**) e busca instantânea por título, ID numérico do Workshop ou tags.

---

## 2. Resolução de Dependências

Para reproduzir papéis de parede do Wallpaper Engine no Linux sob compositores Wayland, você precisa dos seguintes componentes instalados:

### A. O Motor: `linux-wallpaperengine`

O `linux-wallpaperengine` é uma reimplementação open-source do motor do Wallpaper Engine para Linux:

- **Arch Linux / AUR**:
  ```sh
  paru -S linux-wallpaperengine
  ```
  *(ou com `yay -S linux-wallpaperengine`)*

- **Distribuição Pandora Linux / Sistema com GPU Híbrida**:
  Em sistemas com GPUs híbridas (iGPU Intel/AMD + dGPU NVIDIA), a Pandora instala um wrapper dedicado (`~/.local/bin/linux-wallpaperengine`) que direciona a renderização para a placa integrada com drivers Mesa, garantindo máxima economia de bateria e execução suave no Wayland.

- **Verificação da instalação**:
  ```sh
  which linux-wallpaperengine
  linux-wallpaperengine --help
  ```

### B. Utilitários de Sistema: `setsid` e `pkill`

Estes utilitários padrão gerenciam o ciclo de vida dos processos em segundo plano:
- No Arch Linux, estão inclusos nos pacotes `util-linux` e `procps-ng` (instalados por padrão).

### C. Steam & Papéis de Parede do Workshop

Para usar os papéis de parede:
1. Certifique-se de que o cliente Steam está instalado.
2. Inscreva-se nos wallpapers desejados no Steam Workshop do Wallpaper Engine (AppID `431960`).
3. Aguarde o download ser concluído pelo Steam.

---

## 3. Detecção e Localização da Biblioteca

O Perfect Wallpapers localiza seus papéis de parede automaticamente verificando os caminhos padrão do Steam:

- `~/.local/share/Steam/steamapps/workshop/content/431960/`
- `~/.steam/steam/steamapps/workshop/content/431960/`
- Bibliotecas do Steam em outros discos ou partições definidas no arquivo `libraryfolders.vdf`.

### Caminho customizado (Override):
Se a sua biblioteca do Steam estiver em um ponto de montagem incomum, defina o caminho nas configurações do plugin em **Settings → Plugins → Perfect Wallpapers → Custom Wallpaper Engine workshop directory** (`wallpaperengine_dir`).

---

## 4. Integração Wayland & Otimização de Performance

Executar papéis de parede animados no Wayland exige cuidados arquiteturais para evitar janelas indesejadas ou consumo excessivo de bateria:

- **Ancoragem em Camada Wayland (Layer Shell)**:
  O plugin inspeciona os monitores conectados via `noctalia.outputs()` e inicia o motor passando `--screen-root <output> --bg <id>`, ancorando o papel de parede na camada `wlr-layer-shell` de fundo. Ele **nunca** cria janelas soltas na tela.
- **Sincronização da Paleta de Cores**:
  Antes de carregar a cena animada, o plugin envia o preview estático para o Noctalia (`noctalia.setWallpaper()`), permitindo que o Noctalia e o Umbriel adaptem o tema, cores da barra e acentos do sistema para harmonizar com o wallpaper ativo.
- **Suspensão do Papel de Parede Nativo**:
  Enquanto a cena animada estiver em execução, a camada nativa estática do Noctalia é desativada (`mutex.enableNoctaliaWallpaper(false)`), liberando uso de GPU e evitando renderização dupla.
- **Finalização Limpa de Processos**:
  Ao parar ou trocar para uma imagem estática, qualquer processo do `linux-wallpaperengine` é finalizado de forma segura com escalonamento de sinais (`SIGTERM` seguido de `SIGKILL`), restaurando o wallpaper estático.
- **Configurações de Áudio e FPS**:
  - `mute_video`: passa o argumento `--silent` para evitar sons inesperados.
  - `video_fps`: passa o argumento `--fps <alvo>` para travar a taxa de quadros e manter a GPU fria.
