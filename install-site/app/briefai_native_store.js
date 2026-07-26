(function () {
  const pending = new Map();
  let sequence = 0;

  window.briefAiNativeResolve = function (requestId, payload) {
    const entry = pending.get(requestId);
    if (!entry) return;
    pending.delete(requestId);
    clearTimeout(entry.timeout);
    if (payload && payload.ok === false) {
      entry.reject(new Error(payload.error || 'Native Store zahtev nije uspeo.'));
    } else {
      entry.resolve(JSON.stringify(payload || {}));
    }
  };

  window.briefAiNativeStoreAvailable = function () {
    return Boolean(window.BriefAiNative && window.BriefAiNative.postMessage);
  };

  window.briefAiNativeStoreRequest = function (action, rawPayload) {
    if (!window.briefAiNativeStoreAvailable()) {
      return Promise.reject(new Error('Native Store most nije dostupan.'));
    }
    const requestId = `briefai-${Date.now()}-${sequence += 1}`;
    let payload = {};
    if (rawPayload) payload = JSON.parse(rawPayload);
    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        pending.delete(requestId);
        reject(new Error('Native Store odgovor je istekao.'));
      }, 120000);
      pending.set(requestId, {resolve, reject, timeout});
      window.BriefAiNative.postMessage(JSON.stringify({
        requestId,
        action,
        payload,
      }));
    });
  };
})();
