# Guia do Provedor Wallhaven

O [Wallhaven](https://wallhaven.cc/) é uma das maiores plataformas comunitárias de papéis de parede da internet, contando com um acervo gigantesco de arte digital, animes, fotografias de alta resolução e ilustrações para desktop.

O Perfect Wallpapers se integra diretamente com a API do Wallhaven para buscar, navegar, filtrar, cachear e aplicar wallpapers sem precisar abrir o navegador.

---

## 1. Recursos & Filtros de Busca

O Wallhaven no Perfect Wallpapers oferece controle total sobre os filtros oficiais:

- **Categorias**: Alterne entre **General**, **Anime** e **People** para restringir os tópicos pesquisados.
- **Pureza (Purity)**:
  - **SFW** (Safe for Work): ativado por padrão.
  - **Sketchy**: conteúdo levemente sugestivo ou artístico.
  - **NSFW**: conteúdo adulto (exige estritamente uma chave de API gratuita do Wallhaven).
- **Ordenação (Sorting)**: Ordene por **Date added** (data), **Relevance** (relevância), **Random** (aleatório), **Views** (visualizações), **Favorites** (favoritos) ou **Toplist** (mais votados).
- **Filtro de Proporção (Aspect Ratio)**: Filtre por **Any** (qualquer), **16:9**, **16:10**, **21:9** ou **Portrait** (vertical).
- **Filtro de Resolução**:
  - **At least** (pelo menos): busca imagens com resolução mínima em pixels (ex.: mínimo de 2560×1440 ou 3840×2160).
  - **Exact** (exata): busca apenas resoluções exatas para sua tela (ex.: 1920×1080).

---

## 2. Como Obter uma Chave de API Gratuita do Wallhaven

Embora o Wallhaven permita buscas anônimas para imagens SFW, gerar uma chave de API gratuita desbloqueia:
1. **Filtro de conteúdo NSFW** (requer estar autenticado em uma conta com permissão de conteúdo adulto).
2. **Limites de requisição significativamente maiores** (evita erros HTTP 429 durante buscas rápidas).
3. **Acesso a coleções pessoais e favoritos**.

### Passo a passo para gerar sua chave:

1. Crie uma conta gratuita ou faça login em [wallhaven.cc](https://wallhaven.cc/).
2. Acesse as configurações da sua conta: [wallhaven.cc/settings/account](https://wallhaven.cc/settings/account).
3. Role até a seção **API Key**.
4. Caso a chave ainda não esteja gerada, clique em **Generate Key**.
5. Copie a chave alfanumérica de 32 caracteres.
6. No Noctalia:
   - Abra **Settings → Plugins → Perfect Wallpapers** (ou clique no ícone de engrenagem no painel do plugin).
   - Cole o token no campo **Wallhaven API key**.
   - A chave passa a valer imediatamente.

---

## 3. Cache Inteligente & Proteção de Rate Limit

O Wallhaven impõe um limite público de aproximadamente 45 requisições por minuto:

- **Cache de consultas em RAM**: Cada resultado de busca é indexado com hash baseado na tupla exata de parâmetros (`category`, `purity`, `sorting`, `order`, `ratio`, `minWidth`, `minHeight`, `query`, `page`). Ao voltar para abas anteriores ou páginas já vistas, os resultados são retornados instantaneamente da RAM sem disparar novas chamadas de rede.
- **Deduplicação de requisições em trânsito**: Se você alternar rapidamente de aba enquanto uma resposta estiver sendo baixada, a chamada é compartilhada, evitando disparos repetidos.
- **Expiração da sessão**: Os envelopes temporários em RAM (`tmpfs`) expiram sozinhos após 24 horas e são descartados quando o hub fecha ou o serviço reinicia, não deixando sujeira acumulada no SSD/disco.

---

## 4. Aplicação de Papéis de Parede

Ao clicar em qualquer miniatura do Wallhaven na grade:
1. A imagem em resolução completa é baixada para a sua pasta configurada de downloads (por padrão `~/Pictures/Wallpapers/perfect-wallpapers`).
2. A imagem é aplicada no motor nativo do Noctalia via `noctalia.setWallpaper()`.
3. O Noctalia e o Umbriel sincronizam imediatamente a paleta de cores do sistema, tons de destaque e a barra para combinar com o wallpaper novo.
