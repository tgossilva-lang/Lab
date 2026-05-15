const BLOCKED_URLS = [
  "edge://settings",
  "edge://extensions",
  "edge://flags",
  "edge://innovations",
  "edge://edge-ai",
  "edge://copilot",
  "edge://wallet",
  "edge://rewards",
  "edge://management",
  "edge://task-manager",
  "edge://performance",
  "edge://apps",
  "edge://collections",
  "microsoftedge.microsoft.com/addons"
];

const MAX_TENTATIVAS = 3;

function deveBloquear(url) {
  if (!url) return false;
  return BLOCKED_URLS.some(p => url.includes(p));
}

async function bloquearAba(tabId, url) {
  try {
    await chrome.tabs.update(tabId, {
      url: chrome.runtime.getURL("blocked.html") + "?from=" + encodeURIComponent(url)
    });
  } catch (e) {
    console.log("Erro ao bloquear aba:", e);
  }
}

chrome.webNavigation.onBeforeNavigate.addListener((details) => {
  if (details.frameId !== 0) return;
  if (deveBloquear(details.url)) {
    bloquearAba(details.tabId, details.url);
  }
});

chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
  if (changeInfo.url && deveBloquear(changeInfo.url)) {
    bloquearAba(tabId, changeInfo.url);
  }
});
