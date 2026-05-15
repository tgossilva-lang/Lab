(function () {
  if (document.getElementById("__bloqueador__")) return;
  const MAX = 3;
  let tentativas = parseInt(sessionStorage.getItem("bloq_tentativas") || "0");
  document.documentElement.style.overflow = "hidden";
  if (document.body) document.body.style.visibility = "hidden";

  const overlay = document.createElement("div");
  overlay.id = "__bloqueador__";
  overlay.style.cssText = "position:fixed!important;top:0!important;left:0!important;width:100vw!important;height:100vh!important;background:#0a0a0f!important;z-index:2147483647!important;display:flex!important;align-items:center!important;justify-content:center!important;font-family:'Segoe UI',sans-serif!important;";

  overlay.innerHTML = `
    <div style="background:#13131a;border:1px solid #2a2a3a;border-radius:16px;padding:48px 40px;width:380px;text-align:center;box-shadow:0 0 60px rgba(0,100,255,0.15);">
      <div id="__bloq_senha_div__">
        <div style="font-size:52px;margin-bottom:16px;">🔒</div>
        <h2 style="color:#fff;font-size:22px;margin:0 0 8px 0;font-weight:600;">Acesso Restrito</h2>
        <p style="color:#888;font-size:14px;margin:0 0 28px 0;">Esta página está protegida pelo administrador.</p>
        <input id="__bloq_input__" type="password" placeholder="Digite a senha de administrador" autocomplete="off"
          style="width:100%;box-sizing:border-box;padding:13px 16px;background:#1e1e2e;border:1px solid #3a3a5a;border-radius:8px;color:#fff;font-size:15px;margin-bottom:10px;outline:none;" />
        <div id="__bloq_erro__" style="color:#ff4444;font-size:13px;margin-bottom:12px;min-height:18px;"></div>
        <button id="__bloq_btn__" style="width:100%;padding:13px;background:#1a6ef5;border:none;border-radius:8px;color:#fff;font-size:15px;font-weight:600;cursor:pointer;">Desbloquear</button>
        <p id="__bloq_rest__" style="color:#ff9900;font-size:12px;margin-top:12px;min-height:16px;"></p>
      </div>
      <div id="__bloq_negado__" style="display:none;flex-direction:column;align-items:center;">
        <div style="font-size:64px;margin-bottom:20px;">🚫</div>
        <div style="color:#ff4444;font-size:24px;font-weight:700;margin-bottom:12px;">ACESSO NÃO AUTORIZADO</div>
        <p style="color:#888;font-size:14px;line-height:1.6;">Número máximo de tentativas atingido.<br>Esta tentativa foi registrada.</p>
        <div style="background:#1a0000;border:1px solid #ff4444;border-radius:8px;padding:12px 20px;margin:20px 0;color:#ff4444;font-size:13px;font-family:monospace;letter-spacing:1px;">ERRO 403 — ACESSO BLOQUEADO</div>
        <p style="color:#888;font-size:14px;">Entre em contato com o administrador do sistema.</p>
      </div>
    </div>
  `;

  document.documentElement.appendChild(overlay);

  const senhaDiv = document.getElementById("__bloq_senha_div__");
  const negadoDiv = document.getElementById("__bloq_negado__");
  const input = document.getElementById("__bloq_input__");
  const btn = document.getElementById("__bloq_btn__");
  const erro = document.getElementById("__bloq_erro__");
  const rest = document.getElementById("__bloq_rest__");

  if (tentativas >= MAX) {
    senhaDiv.style.display = "none";
    negadoDiv.style.display = "flex";
  } else {
    input.focus();
  }

  function tentar() {
    chrome.storage.local.get("password", (data) => {
      const senha = data.password || "admin123";
      if (input.value === senha) {
        sessionStorage.removeItem("bloq_tentativas");
        overlay.remove();
        document.documentElement.style.overflow = "";
        if (document.body) document.body.style.visibility = "";
      } else {
        tentativas++;
        sessionStorage.setItem("bloq_tentativas", tentativas);
        input.value = "";
        if (tentativas >= MAX) {
          senhaDiv.style.display = "none";
          negadoDiv.style.display = "flex";
          return;
        }
        erro.textContent = `Senha incorreta.`;
        rest.textContent = `⚠️ ${MAX - tentativas} tentativa(s) restante(s)`;
        input.focus();
      }
    });
  }

  btn.addEventListener("click", tentar);
  input.addEventListener("keydown", (e) => { if (e.key === "Enter") tentar(); });
})();
