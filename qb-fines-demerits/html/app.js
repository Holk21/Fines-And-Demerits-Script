const wrap = document.getElementById('wrap');
const playersEl = document.getElementById('players');
const manualIdEl = document.getElementById('manualId');
const catEl = document.getElementById('cat');
const offEl = document.getElementById('off');
const amountEl = document.getElementById('amount');
const pointsEl = document.getElementById('points');
const noteEl = document.getElementById('note');
const methodEl = document.getElementById('method');

const summaryTarget = document.getElementById('summaryTarget');
const summaryOffence = document.getElementById('summaryOffence');
const summaryAmount = document.getElementById('summaryAmount');
const summaryPoints = document.getElementById('summaryPoints');

const closeBtn = document.getElementById('closeBtn');
const issueBtn = document.getElementById('issueBtn');

let state = {
  categories: [],
  players: [],
  currentPlayerId: null,
  currentPlayerLabel: null,
  currentOffence: null,
  defaults: { payment: 'unpaid' }
};

/* Hard-hide on load */
(function () {
  wrap.classList.remove('show');
  wrap.classList.add('hidden');
  wrap.style.display = 'none';
})();

/* Open/Close messages from client.lua */
window.addEventListener('message', (e) => {
  const { action, data } = e.data || {};
  if (action === 'openTablet') {
    state.categories = data?.categories || [];
    state.players    = data?.players || [];
    state.defaults   = data?.defaults || state.defaults;

    buildPlayers();
    buildCategories();
    methodEl.value = state.defaults.payment || 'unpaid';
    refreshSummary();

    wrap.classList.add('show');
    wrap.classList.remove('hidden');
    wrap.style.display = 'grid'; // SHOW
  } else if (action === 'forceHide' || action === 'closeTablet') {
    hideUI();
  }
});

/* Close button */
closeBtn.addEventListener('click', () => {
  fetch(`https://${GetParentResourceName()}/closeTablet`, { method: 'POST' });
  hideUI();
});

function hideUI() {
  wrap.classList.remove('show');
  wrap.classList.add('hidden');
  wrap.style.display = 'none'; // HIDE
}

/* -------- Players -------- */
function buildPlayers() {
  playersEl.innerHTML = '';
  state.currentPlayerId = null;
  state.currentPlayerLabel = null;

  (state.players || []).forEach(p => {
    const el = document.createElement('div');
    el.className = 'player';
    el.innerHTML = `<div class="name">${p.name}</div><div class="dist">${p.dist}m · ID ${p.id}</div>`;
    el.onclick = () => {
      state.currentPlayerId = p.id;
      state.currentPlayerLabel = `${p.name} (ID ${p.id})`;
      refreshSummary();
    };
    playersEl.appendChild(el);
  });
}

/* ---- Categories & Offences ---- */
function buildCategories() {
  catEl.innerHTML = '';
  (state.categories || []).forEach((c, i) => {
    const opt = document.createElement('option');
    opt.value = i;
    opt.textContent = c.label;
    catEl.appendChild(opt);
  });
  if (state.categories.length) {
    catEl.value = 0;
    buildOffences(0);
  } else {
    offEl.innerHTML = '';
    setOffence(null);
  }
}

function buildOffences(catIdx) {
  const cat = state.categories[catIdx] || { offences: [] };
  offEl.innerHTML = '';
  (cat.offences || []).forEach((o, i) => {
    const opt = document.createElement('option');
    opt.value = i;
    opt.textContent = o.label;
    opt.dataset.amount = o.amount ?? 0;
    opt.dataset.points = o.points ?? 0;
    offEl.appendChild(opt);
  });
  if (cat.offences && cat.offences.length) {
    offEl.value = 0;
    setOffence(cat.offences[0]);
  } else {
    setOffence(null);
  }
}

catEl.onchange = () => {
  const idx = parseInt(catEl.value || '0', 10);
  buildOffences(idx);
};

offEl.onchange = () => {
  const idxC = parseInt(catEl.value || '0', 10);
  const idxO = parseInt(offEl.value || '0', 10);
  const off = state.categories[idxC]?.offences?.[idxO] || null;
  setOffence(off);
};

function setOffence(off) {
  state.currentOffence = off;
  if (!off) {
    amountEl.value = '';
    pointsEl.value = '';
    summaryOffence.textContent = '—';
    summaryAmount.textContent = '$0';
    summaryPoints.textContent = '0';
    return;
  }
  amountEl.value = off.amount ?? 0;
  pointsEl.value = off.points ?? 0;
  summaryOffence.textContent = off.label;
  summaryAmount.textContent = `$${off.amount ?? 0}`;
  summaryPoints.textContent = `${off.points ?? 0}`;
}

/* -------- Summary & Issue -------- */
amountEl.oninput = refreshSummary;
pointsEl.oninput = refreshSummary;
manualIdEl.oninput = refreshSummary;

function refreshSummary() {
  const manualId = parseInt(manualIdEl.value || '0', 10);
  const targetText = state.currentPlayerLabel || (manualId > 0 ? ("ID " + manualId) : "—");
  summaryTarget.textContent = targetText;
  summaryAmount.textContent = `$${parseInt(amountEl.value || '0', 10) || 0}`;
  summaryPoints.textContent = `${parseInt(pointsEl.value || '0', 10) || 0}`;
}

issueBtn.onclick = () => {
  const manualId = parseInt(manualIdEl.value || '0', 10);
  const targetId = state.currentPlayerId || (manualId > 0 ? manualId : null);
  if (!targetId) return bump('Select a nearby player or enter an ID');
  if (!state.currentOffence) return bump('Select an offence');

  const payload = {
    target: targetId,
    offence: {
      code: state.currentOffence.code || "UNKNOWN",
      label: state.currentOffence.label,
      amount: parseInt(amountEl.value || '0', 10) || 0,
      points: parseInt(pointsEl.value || '0', 10) || 0
    },
    method: methodEl.value || 'unpaid',
    note: (noteEl.value || '').toString().slice(0,120)
  };

  fetch(`https://${GetParentResourceName()}/issueFine`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  }).then(() => {
    fetch(`https://${GetParentResourceName()}/closeTablet`, { method: 'POST' });
    hideUI();
  });
};

/* Tiny inline “toast” using the close button */
function bump(msg) {
  const old = closeBtn.textContent;
  closeBtn.textContent = '✕ ' + msg;
  setTimeout(() => { closeBtn.textContent = old; }, 1500);
}

/* ESC closes */
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') hideUI();
});
