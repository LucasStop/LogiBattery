// Ícones aproximam SF Symbols (computermouse, keyboard, bolt.fill).
const I={mouse:'<rect x="5" y="2" width="10" height="16" rx="5"/><path d="M10 2v6"/>',
 keyboard:'<rect x="1.5" y="5" width="17" height="10" rx="2"/><path d="M5 9h.01M8 9h.01M11 9h.01M14 9h.01M6 12h8"/>',
 bolt:'<path d="M11 2 4 11h5l-1 7 7-9h-5z" fill="currentColor"/>'};
const svg=n=>`<svg width="16" height="16" viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${I[n]}</svg>`;
document.querySelectorAll('[data-i]').forEach(e=>e.innerHTML=svg(e.dataset.i));
// Renderiza cada .pair em claro e escuro a partir de um único markup (protótipo, não vai para o app).
document.querySelectorAll('.pair').forEach(p=>{
  const html=p.innerHTML;
  p.innerHTML=['light','dark'].map(t=>`<div class="theme ${t}"><div style="width:100%"><p class="tag">${t==='light'?'Claro':'Escuro'}</p><div style="display:flex;gap:16px;flex-wrap:wrap;align-items:flex-start">${html}</div></div></div>`).join('');
});
