/* Main site JS: extracted from _layouts/default.html */
/* 1) Banner typing interaction */
document.addEventListener("DOMContentLoaded", function () {
  const typedEl = document.querySelector(".site-banner__typed");
  const cursorEl = document.querySelector(".site-banner__cursor");
  const commandLine = document.querySelector(".site-banner__command-line");
  const promptLabel = commandLine ? commandLine.querySelector(".site-banner__prompt-label") : null;
  if (!typedEl || !cursorEl || !commandLine) return;

  const segments = [
    { text: "49", className: "segment-leading" },
    { text: "th", className: "segment-small" },
    { text: "IT", className: "segment-trailing" },
  ];

  if (promptLabel) {
    promptLabel.textContent = promptLabel.dataset.label || "core.gacis.ak:>";
  }

  const letterDelay = 280;
  let typingActive = false;
  let typedOnce = false;

  typedEl.innerHTML = "";
  cursorEl.classList.remove("is-complete");
  cursorEl.setAttribute("role", "button");
  cursorEl.setAttribute("tabindex", "0");
  cursorEl.setAttribute("aria-label", "Type command 49thIT");

  function typeCommand() {
    if (typingActive || typedOnce) return;
    typingActive = true;
    commandLine.classList.add("is-active");
    cursorEl.classList.add("is-typing");
    typedEl.innerHTML = "";
    cursorEl.classList.add("is-hidden");

    let segmentIndex = 0;
    let charIndex = 0;
    let currentSpan = null;

    function finishTyping() {
      cursorEl.classList.remove("is-typing");
      cursorEl.classList.add("is-complete");
      cursorEl.classList.add("is-hidden");
      cursorEl.removeAttribute("role");
      cursorEl.removeAttribute("tabindex");
      typingActive = false;
      typedOnce = true;
    }

    function step() {
      if (segmentIndex >= segments.length) {
        finishTyping();
        return;
      }

      const segment = segments[segmentIndex];
      if (!currentSpan) {
        currentSpan = document.createElement("span");
        if (segment.className) currentSpan.className = segment.className;
        typedEl.appendChild(currentSpan);
      }

      currentSpan.textContent += segment.text.charAt(charIndex);
      charIndex += 1;

      if (charIndex >= segment.text.length) {
        segmentIndex += 1;
        charIndex = 0;
        currentSpan = null;
      }

      if (segmentIndex >= segments.length) {
        finishTyping();
      } else {
        setTimeout(step, letterDelay);
      }
    }

    setTimeout(step, letterDelay);
  }

  function handleActivation(event) {
    if (event.type === "keydown" && event.key !== "Enter" && event.key !== " ") {
      return;
    }
    event.preventDefault();
    typeCommand();
  }

  cursorEl.addEventListener("click", handleActivation);
  cursorEl.addEventListener("keydown", handleActivation);
});

/* 2) Continue reading panel (uses localStorage + optional meta fallback) */
(function () {
  const storageKey = "49thIT:lastPath";

  function onReady(fn) {
    if (document.readyState !== "loading") {
      fn();
    } else {
      document.addEventListener("DOMContentLoaded", fn, { once: true });
    }
  }

  onReady(function () {
    try {
      const currentPath = window.location.pathname;
      if (currentPath && currentPath !== "/" && !currentPath.startsWith("/assets/")) {
        localStorage.setItem(storageKey, currentPath);
      }

      const continueLink = document.querySelector("[data-continue-link]");
      if (!continueLink) return;

      const panel = continueLink.closest("[data-continue-panel]");
      const messageEl = panel ? panel.querySelector("[data-continue-message]") : null;
      const storedPath = localStorage.getItem(storageKey);

      // Try data-fallback first (set in index.md), then meta fallback in head
      const fallbackMeta = document.querySelector('meta[name="fallback-episode"]');
      const metaFallback = fallbackMeta ? fallbackMeta.content : null;

      const targetPath =
        (storedPath && storedPath !== "/" ? storedPath : continueLink.dataset.fallback) || metaFallback;

      if (!targetPath) return;

      continueLink.href = targetPath;

      const hasVisited = Boolean(storedPath && storedPath !== "/");
      continueLink.textContent = hasVisited
        ? "pickup where you left off..."
        : "get started with episode001...";

      if (panel) {
        panel.classList.add("is-active");
      }

      if (messageEl) {
        messageEl.textContent = hasVisited ? "Welcome back!" : "Welcome!";
      }
    } catch (error) {
      console.warn("Continue reading unavailable:", error);
    }
  });
})();
