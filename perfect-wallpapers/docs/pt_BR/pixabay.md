# Guia do Provedor Pixabay

O [Pixabay](https://pixabay.com/) é uma comunidade criativa global que compartilha fotos, ilustrações, vetores e vídeos em alta resolução livres de direitos autorais sob a Licença de Conteúdo Pixabay.

O Perfect Wallpapers se integra diretamente com a API REST oficial do Pixabay para permitir navegação e aplicação direta de fotos e vídeos em loop.

---

## 1. Recursos & Tipos de Mídia

- **Duas Abas de Mídia**:
  - **Images**: Navegue por milhões de fotografias de alta qualidade, ilustrações digitais e vetores.
  - **Videos**: Navegue por vídeos em loop de alta definição (HD/4K) para fundos de tela animados.
- **Filtros de Busca e Exploração**:
  - **Category**: Filtre por mais de 20 categorias temáticas, incluindo *Natureza*, *Fundos*, *Ciência*, *Computador*, *Arquitetura*, *Sentimentos* e *Viagem*.
  - **Order**: Alterne entre **Popular** (mais populares) e **Latest** (mais recentes).
  - **Editor's Choice**: Restrinja os resultados apenas a mídias premiadas e selecionadas a dedo pela equipe editorial do Pixabay.
  - **Orientation**: Filtre por **Horizontal**, **Vertical** ou **All** (todas).
  - **SafeSearch**: Aplica filtro de conteúdo seguro para todas as idades.
  - **Preferência de Qualidade de Vídeo**: Configure o tamanho de resolução de streaming preferido (**Large**, **Medium**, **Small** ou **Tiny**).

---

## 2. Como Obter uma Chave de API Gratuita do Pixabay

O Pixabay exige o envio de uma chave de API para liberar os endpoints de consulta. As contas e as chaves de API são 100% gratuitas para uso pessoal.

### Passo a passo para obter sua chave:

1. Registre-se ou faça login em [pixabay.com](https://pixabay.com/).
2. Abra a página de documentação oficial da API: [pixabay.com/api/docs](https://pixabay.com/api/docs/).
3. Role até a seção **Search Images** ou **Parameters**.
4. Localize a caixa verde contendo sua chave pessoal exclusiva:
   ```text
   key (str): Your API key: XXXXXXX-XXXXXXXXXXXXXXXXXXXXXXXXX
   ```
5. Copie a chave inteira.
6. No Noctalia:
   - Abra **Settings → Plugins → Perfect Wallpapers** (ou clique na engrenagem no painel do plugin).
   - Cole o token no campo **Pixabay API key**.
   - O plugin autenticará imediatamente e carregará o acervo do Pixabay.

---

## 3. Motor de Papéis de Parede em Vídeo (`mpvpaper`)

Ao escolher um vídeo do Pixabay, o Perfect Wallpapers coordena a execução com o `mpvpaper` para reproduzir o loop suavemente como fundo de tela no Wayland:

- **Aceleração por Hardware**: A decodificação de vídeo pode utilizar a GPU ativando a configuração `hardware_decode` (`--hwdec=auto`).
- **Limite de FPS**: Para economizar bateria em laptops e minimizar uso de GPU, você pode definir um limite de quadros por segundo (ex.: 30 FPS ou 60 FPS) nas configurações do plugin via `video_fps`.
- **Controle de Áudio**: Silencie o áudio dos vídeos automaticamente com a opção `mute_video`.
- **Exclusão Mútua**: Aplicar um vídeo encerra processos anteriores de outros daemons ou do Wallpaper Engine para evitar disputa de recursos.

---

## 4. Política de Download Local

Os Termos de Serviço da API do Pixabay proíbem estritamente o hotlink permanente das URLs de sua CDN em desktops.

Para respeitar as diretrizes do provedor e garantir funcionamento offline:
1. Ao selecionar um wallpaper ou vídeo, o Perfect Wallpapers faz o download completo do arquivo para o seu diretório local (`~/Pictures/Wallpapers/perfect-wallpapers`).
2. O arquivo local baixado é então aplicado na área de trabalho.
3. Previews e páginas intermediárias de busca permanecem na memória RAM temporária (`tmpfs`), evitando escritas desnecessárias no disco.
