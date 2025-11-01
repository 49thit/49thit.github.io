---
layout: default
title: "An Alaskan serial adventure in IT..."
permalink: /
fallback_episode: "/episodeNEXT"
---

{% assign posts_with_episode = site.posts | where_exp: "p", "p.episode" %}
{% if posts_with_episode and posts_with_episode.size > 0 %}
  {% assign preferred_first_post = site.posts | sort: "episode" | first %}
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
</article>
