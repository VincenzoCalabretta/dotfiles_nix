async function getCookiesForDomain(domain) {
  const url = `https://${domain}`;
  const [csrf, session] = await Promise.all([
    browser.cookies.get({ url, name: "csrftoken" }),
    browser.cookies.get({ url, name: "LEETCODE_SESSION" }),
  ]);
  if (csrf && session) return { csrf, session, domain };
  return null;
}

function copyToClipboard(text) {
  const textarea = document.createElement("textarea");
  textarea.value = text;
  textarea.style.position = "fixed";
  textarea.style.opacity = "0";
  document.body.appendChild(textarea);
  textarea.focus();
  textarea.select();
  document.execCommand("copy");
  document.body.removeChild(textarea);
}

function flashBadge(text, color) {
  browser.browserAction.setBadgeText({ text });
  browser.browserAction.setBadgeBackgroundColor({ color });
  setTimeout(() => browser.browserAction.setBadgeText({ text: "" }), 1500);
}

browser.browserAction.onClicked.addListener(async (tab) => {
  const candidates = [];
  if (tab && tab.url) {
    try {
      const host = new URL(tab.url).hostname;
      if (host.endsWith("leetcode.cn")) candidates.push("leetcode.cn");
      else if (host.endsWith("leetcode.com")) candidates.push("leetcode.com");
    } catch (e) {
      // active tab isn't a leetcode page; fall through to defaults below
    }
  }
  if (!candidates.includes("leetcode.com")) candidates.push("leetcode.com");
  if (!candidates.includes("leetcode.cn")) candidates.push("leetcode.cn");

  for (const domain of candidates) {
    const found = await getCookiesForDomain(domain);
    if (found) {
      const cookieStr = `csrftoken=${found.csrf.value}; LEETCODE_SESSION=${found.session.value}`;
      copyToClipboard(cookieStr);
      flashBadge("✓", "#2ecc71");
      return;
    }
  }
  flashBadge("✗", "#e74c3c");
});
