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

    const autoRevealDelay = 10000;
    revealTimerId = window.setTimeout(function () {
      // Auto-trigger typing shortly after load if not already revealed/typing
      if (!typingActive && !typedOnce) {
        typeCommand();
      }
    }, autoRevealDelay);
  }
});

(function () {
  function onReady(fn) {
    if (document.readyState !== "loading") fn();
    else document.addEventListener("DOMContentLoaded", fn, { once: true });
  }

  function debounce(fn, wait) {
    let t;
    return function () {
      clearTimeout(t);
      t = setTimeout(fn, wait);
    };
  }

  function clampFsImage() {
    const fs = document.querySelector(".follow-subscribe");
    if (!fs) return;
    const links = fs.querySelector(".fs-links");
    const box = fs.querySelector(".fs-image");
    const img = fs.querySelector(".fs-image img");
    if (!links || !box || !img) return;

    const isSingleCol = window.matchMedia("(max-width: 820px)").matches;
    if (isSingleCol) {
      box.style.height = "";
      box.style.marginTop = "";
      img.style.height = "";
      img.style.maxHeight = "";
      return;
    }

    // Compute exact vertical span from top of first button to bottom of last button
    const items = links.querySelectorAll(".fs-link");
    if (!items.length) {
      const h = Math.ceil(links.getBoundingClientRect().height);
      box.style.marginTop = "0px";
      box.style.height = h + "px";
      img.style.height = "100%";
      img.style.maxHeight = "100%";
      img.style.objectFit = "contain";
      img.style.width = "100%";
      return;
    }

    const firstRect = items[0].getBoundingClientRect();
    const lastRect = items[items.length - 1].getBoundingClientRect();
    const linksRect = links.getBoundingClientRect();

    const topOffset = Math.max(0, Math.round(firstRect.top - linksRect.top));
    const totalHeight = Math.max(0, Math.round(lastRect.bottom - firstRect.top));

    // Align the image box top with the first button, and match total button stack height
    box.style.marginTop = topOffset + "px";
    box.style.height = totalHeight + "px";
    img.style.height = "100%";
    img.style.maxHeight = "100%";
    img.style.objectFit = "contain";
    img.style.width = "100%";
  }

  onReady(function () {
    clampFsImage();
    const img = document.querySelector(".fs-image img");
    if (img) {
      if (img.complete) {
        clampFsImage();
      } else {
        img.addEventListener("load", clampFsImage, { once: true });
      }
    }
  });
  window.addEventListener("load", clampFsImage);
  window.addEventListener("resize", debounce(clampFsImage, 150));
})();

/* 4) Read-all binge image lightbox */
(function () {
  function ready(fn) {
    if (document.readyState !== "loading") {
      fn();
    } else {
      document.addEventListener("DOMContentLoaded", fn, { once: true });
    }
  }

  ready(function () {
    const triggers = document.querySelectorAll(".read-all__image-trigger");
    const lightbox = document.getElementById("read-all-lightbox");
    if (!triggers.length || !lightbox) return;

    const imageEl = lightbox.querySelector("img");
    const dismissers = lightbox.querySelectorAll("[data-lightbox-dismiss]");
    let activeTrigger = null;

    function openLightbox(trigger) {
      const src = trigger.getAttribute("data-full-src");
      if (!src) return;
      const alt = trigger.getAttribute("data-image-alt") || trigger.getAttribute("aria-label") || "";
      activeTrigger = trigger;
      imageEl.src = src;
      imageEl.alt = alt;
      lightbox.classList.add("is-active");
      lightbox.setAttribute("aria-hidden", "false");
      document.body.style.overflow = "hidden";
      const closeButton = lightbox.querySelector(".read-all-lightbox__close");
      if (closeButton) closeButton.focus();
    }

    function closeLightbox() {
      if (!lightbox.classList.contains("is-active")) return;
      lightbox.classList.remove("is-active");
      lightbox.setAttribute("aria-hidden", "true");
      imageEl.src = "";
      document.body.style.overflow = "";
      if (activeTrigger) {
        activeTrigger.focus();
        activeTrigger = null;
      }
    }

    triggers.forEach(function (trigger) {
      trigger.addEventListener("click", function () {
        openLightbox(trigger);
      });
    });

    dismissers.forEach(function (dismissEl) {
      dismissEl.addEventListener("click", closeLightbox);
    });

    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape") {
        closeLightbox();
      }
    });
  });
})();
