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
  let revealTimerId = null;
  const headerKey = "49thIT:headerRevealed";
  let revealed = false;
  try {
    const navEntries = performance.getEntriesByType ? performance.getEntriesByType("navigation") : null;
    const nav = navEntries && navEntries.length ? navEntries[0] : null;
    const isReload = nav ? nav.type === "reload" : (performance.navigation && performance.navigation.type === 1);
    if (isReload) {
      localStorage.removeItem(headerKey);
    }
    revealed = localStorage.getItem(headerKey) === "1";
  } catch (e) {
    revealed = false;
  }

  if (promptLabel) {
    // Reset banner reveal when clicking the prompt label (navigates to site root)
    promptLabel.addEventListener("click", function () {
      try {
        localStorage.removeItem(headerKey);
      } catch (e) {}
      resetHeaderReveal();
    });
    // Keyboard activation support (Enter/Space)
    promptLabel.addEventListener("keydown", function (e) {
      if (e.key === "Enter" || e.key === " ") {
        try {
          localStorage.removeItem(headerKey);
        } catch (err) {}
        resetHeaderReveal();
      }
    });
  }

  function applyRevealedState() {
    commandLine.classList.add("is-active");
    typedEl.innerHTML = "";
    const segs = [
      { text: "49", className: "segment-leading" },
      { text: "th", className: "segment-small" },
      { text: "IT", className: "segment-trailing" },
    ];
    segs.forEach(function (seg) {
      const span = document.createElement("span");
      if (seg.className) span.className = seg.className;
      span.textContent = seg.text;
      typedEl.appendChild(span);
    });
    cursorEl.classList.remove("is-typing");
    cursorEl.classList.add("is-complete");
    cursorEl.classList.add("is-hidden");
    cursorEl.removeAttribute("role");
    cursorEl.removeAttribute("tabindex");
  }

  if (!revealed) {
    typedEl.innerHTML = "";
    cursorEl.classList.remove("is-complete");
    cursorEl.setAttribute("role", "button");
    cursorEl.setAttribute("tabindex", "0");
    cursorEl.setAttribute("aria-label", "Type command 49thIT");
  } else {
    typedOnce = true;
    applyRevealedState();
  }

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
      try {
        localStorage.setItem(headerKey, "1");
      } catch (e) {}
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

  function resetHeaderReveal() {
    try {
      localStorage.removeItem(headerKey);
    } catch (e) {}
    revealed = false;
    typedOnce = false;
    typingActive = false;
    commandLine.classList.remove("is-active");
    typedEl.innerHTML = "";
    cursorEl.classList.remove("is-typing");
    cursorEl.classList.remove("is-complete");
    cursorEl.classList.remove("is-hidden");
    cursorEl.setAttribute("role", "button");
    cursorEl.setAttribute("tabindex", "0");
    cursorEl.setAttribute("aria-label", "Type command 49thIT");
    // Ensure handlers are attached (remove first to avoid duplicates)
    cursorEl.removeEventListener("click", handleActivation);
    cursorEl.removeEventListener("keydown", handleActivation);
    cursorEl.addEventListener("click", handleActivation);
    cursorEl.addEventListener("keydown", handleActivation);
    // Restart auto trigger timer
    if (revealTimerId) {
      clearTimeout(revealTimerId);
    }
    revealTimerId = window.setTimeout(function () {
      if (!typingActive && !typedOnce) {
        typeCommand();
      }
    }, 30000);
  }

  if (!revealed) {
    cursorEl.addEventListener("click", handleActivation);
    cursorEl.addEventListener("keydown", handleActivation);

    revealTimerId = window.setTimeout(function () {
      // Auto-trigger typing after 30 seconds if not already revealed/typing
      if (!typingActive && !typedOnce) {
        typeCommand();
      }
    }, 30000);
  }
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
