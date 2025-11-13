
Pesquisar no google tem textarea[jsname="yZiJbe"], dar enter, e os resultados são links selecionados por elementos com seletor 'a[jsname="UWckNb"]'.


Pesquisar constantemente também inclui abrir o primeiro resultado ou outra ação inferida

## Youtube:
🎥 Resultados e Blocos de Vídeo

Cada resultado de vídeo no YouTube é composto de uma estrutura padrão:

<ytd-video-renderer> : componente pai de cada vídeo em resultados de busca.

Miniatura: "#thumbnail" img ou .yt-lockup-view-model__content-image

Título: #video-title

Canal: ytd-channel-name a

Estatísticas: #metadata-line span (visualizações e tempo)

Duração: ytd-thumbnail-overlay-time-status-renderer span

Outros contextos de vídeo usam variantes como:

ytd-rich-grid-media — usado na homepage (feed de recomendações).

ytd-rich-item-renderer — estrutura envoltória genérica para carrosséis e listas.

📚 Listas e Navegação

Menu lateral — #guide-content dentro de ytd-guide-renderer

Entradas principais: ytd-guide-entry-renderer a#endpoint

Grupos e separadores (ytd-guide-section-renderer) dividem tópicos como “Início”, “Shorts”, “Inscrições”.

Carrosséis de seções — ytd-rich-shelf-renderer

Título da seção: #title-container span#title

Miniaturas internas: ytd-rich-grid-media img#img