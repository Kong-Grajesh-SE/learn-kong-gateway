<script setup>
import { useData, useRoute } from 'vitepress'
import { ref, computed } from 'vue'

const { site, page } = useData()
const route = useRoute()
const submitted = ref(false)
const selected = ref('')

const githubRepo = computed(() => {
  const editLink = site.value.themeConfig?.editLink?.pattern || ''
  const match = editLink.match(/github\.com\/([^/]+\/[^/]+)/)
  return match ? match[1] : ''
})

const issueUrl = computed(() => {
  if (!githubRepo.value) return ''
  const title = encodeURIComponent(`Feedback: ${page.value.title || route.path}`)
  const body = encodeURIComponent(
    `**Page:** ${route.path}\n**URL:** ${route.path}\n\n**Feedback:**\n\n_Please describe the issue or suggestion:_\n`
  )
  return `https://github.com/${githubRepo.value}/issues/new?title=${title}&body=${body}&labels=feedback`
})

function handleFeedback(type) {
  selected.value = type
  submitted.value = true
}
</script>

<template>
  <div class="doc-feedback" v-if="page.frontmatter?.layout !== 'home'">
    <div class="feedback-divider"></div>
    <div v-if="!submitted" class="feedback-prompt">
      <p class="feedback-question">Was this page helpful?</p>
      <div class="feedback-actions">
        <button class="feedback-btn yes" @click="handleFeedback('yes')" aria-label="Yes, this page was helpful">
          <span class="icon">👍</span> Yes
        </button>
        <button class="feedback-btn no" @click="handleFeedback('no')" aria-label="No, this page was not helpful">
          <span class="icon">👎</span> No
        </button>
      </div>
    </div>
    <div v-else class="feedback-thanks">
      <p v-if="selected === 'yes'">Thanks for your feedback! 🎉</p>
      <p v-else>We're sorry to hear that. Help us improve:</p>
    </div>
    <div class="feedback-links">
      <a v-if="issueUrl" :href="issueUrl" target="_blank" rel="noopener noreferrer" class="feedback-link">
        📝 Report an issue or suggest an improvement
      </a>
    </div>
  </div>
</template>

<style scoped>
.doc-feedback {
  margin-top: 3rem;
  padding-top: 1.5rem;
}

.feedback-divider {
  border-top: 1px solid var(--vp-c-divider);
  margin-bottom: 1.5rem;
}

.feedback-question {
  font-size: 0.95rem;
  font-weight: 600;
  color: var(--vp-c-text-1);
  margin-bottom: 0.75rem;
}

.feedback-prompt {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.5rem;
}

.feedback-actions {
  display: flex;
  gap: 0.75rem;
}

.feedback-btn {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  padding: 0.45rem 1.1rem;
  border-radius: 8px;
  font-size: 0.85rem;
  font-weight: 500;
  cursor: pointer;
  border: 1px solid var(--vp-c-divider);
  background: var(--vp-c-bg-soft);
  color: var(--vp-c-text-2);
  transition: all 0.2s ease;
}

.feedback-btn:hover {
  border-color: var(--vp-c-brand-1);
  color: var(--vp-c-brand-1);
  background: var(--vp-c-brand-soft);
}

.feedback-btn .icon {
  font-size: 1rem;
}

.feedback-thanks {
  text-align: center;
  font-size: 0.9rem;
  color: var(--vp-c-text-2);
}

.feedback-links {
  text-align: center;
  margin-top: 0.75rem;
}

.feedback-link {
  font-size: 0.85rem;
  color: var(--vp-c-brand-1);
  text-decoration: none;
  transition: color 0.2s;
}

.feedback-link:hover {
  color: var(--vp-c-brand-2);
  text-decoration: underline;
}
</style>
