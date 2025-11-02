---
layout: default
title: "An Alaskan serial adventure in IT..."
permalink: /
fallback_episode: "/episode001-palin-picks-the-right-shoes"
---

{% assign posts_with_episode = site.posts | where_exp: "p", "p.episode" %}
{% if posts_with_episode and posts_with_episode.size > 0 %}
  {% assign preferred_first_post = posts_with_episode | sort: "episode" | first %}
{% else %}
  {% assign preferred_first_post = site.posts | where_exp: "post", "post.url contains 'episode001'" | first %}
{% endif %}
{% assign fallback_episode_path = preferred_first_post.url | default: page.fallback_episode %}

<article class="post-article">
  <div class="continue-panel" data-continue-panel>
    <header class="post-article__header">
      <h1 class="post-article__title">{{ page.title }}</h1>
    </header>
    <div class="post-article__content">
      <p data-continue-message>Start with Episode 001.</p>
      <p class="continue-panel__note"></p>
    </div>
    <footer class="post-article__footer">
      <a class="continue-panel__cta post-article__next-button" data-continue-link data-fallback="{{ fallback_episode_path }}" href="{{ fallback_episode_path }}">Get started with Episode 001...</a>
    </footer>
  </div>

  <div class="follow-subscribe" aria-label="Follow and subscribe">
    <h3>Follow and subscribe</h3>

    <div class="fs-links">
      <span class="fs-link is-disabled" aria-disabled="true" title="Email subscription coming soon">
        <svg class="fs-icon" viewBox="0 0 24 24" aria-hidden="true">
          <rect x="3" y="6" width="18" height="12" rx="0" fill="none" stroke="currentColor" stroke-width="2"/>
          <path d="M4 8l8 6 8-6" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>
        <span>Subscribe (coming soon)</span>
      </span>

      <a class="fs-link" href="https://medium.com/@49thit" target="_blank" rel="noopener" aria-label="Follow on Medium">
        <img class="fs-icon-img" src="https://cdn.simpleicons.org/medium/12100E" alt="" aria-hidden="true" width="32" height="32" loading="lazy" decoding="async" />
        <span>Medium</span>
      </a>

      <a class="fs-link" href="https://www.wattpad.com/story/345862277-49th-it" target="_blank" rel="noopener" aria-label="Read on Wattpad">
        <img class="fs-icon-img" src="https://www.wattpad.com/favicon.ico" alt="" aria-hidden="true" width="28" height="28" loading="lazy" decoding="async" />
        <span>Wattpad</span>
      </a>

      <a class="fs-link" href="https://49thit.substack.com/" target="_blank" rel="noopener" aria-label="Follow on Substack">
        <img class="fs-icon-img" src="https://substack.com/favicon.ico" alt="" aria-hidden="true" width="28" height="28" loading="lazy" decoding="async" />
        <span>Substack</span>
      </a>

      <a class="fs-link" href="https://x.com/49thIt" target="_blank" rel="noopener" aria-label="Follow on X (Twitter)">
        <img class="fs-icon-img" src="https://x.com/favicon.ico" alt="" aria-hidden="true" width="28" height="28" loading="lazy" decoding="async" />
        <span>X</span>
      </a>

      <a class="fs-link" href="https://bsky.app/profile/49thit.bsky.social" target="_blank" rel="noopener" aria-label="Follow on Bluesky">
        <img class="fs-icon-img" src="https://cdn.simpleicons.org/bluesky/0285FF" alt="" aria-hidden="true" width="32" height="32" loading="lazy" decoding="async" />
        <span>Bluesky</span>
      </a>
      <span class="fs-link is-disabled" aria-disabled="true" title="Patreon coming soon">
        <img class="fs-icon-img" src="https://cdn.simpleicons.org/patreon/052D49" alt="" aria-hidden="true" width="32" height="32" loading="lazy" decoding="async" />
        <span>Patreon (coming soon)</span>
      </span>
    </div>

    <div class="fs-image">
      <img src="{{ '/assets/img/sidebar.png' | relative_url }}" alt="49thIT promo" loading="lazy" decoding="async" />
    </div>
  </div>
</article>
