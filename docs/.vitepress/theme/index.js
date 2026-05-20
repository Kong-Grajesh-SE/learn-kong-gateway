// .vitepress/theme/index.js
// Extends the default VitePress theme with Kong brand styling
import DefaultTheme from 'vitepress/theme'
import './kong-design-system.css'
import './style.css'
import DocFeedback from './DocFeedback.vue'
import { h } from 'vue'

export default {
  extends: DefaultTheme,
  Layout() {
    return h(DefaultTheme.Layout, null, {
      'doc-after': () => h(DocFeedback),
    })
  },
}
