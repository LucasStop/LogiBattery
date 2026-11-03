// Ícones aproximam SF Symbols (computermouse, keyboard, laptopcomputer, headphones, bolt.fill e os selos de conexão).
const I={mouse:'<rect x="5" y="2" width="10" height="16" rx="5"/><path d="M10 2v6"/>',
 keyboard:'<rect x="1.5" y="5" width="17" height="10" rx="2"/><path d="M5 9h.01M8 9h.01M11 9h.01M14 9h.01M6 12h8"/>',
 laptop:'<rect x="4" y="4" width="12" height="9" rx="1"/><path d="M2 16h16"/>',
 headphones:'<path d="M3 13v-3a7 7 0 0 1 14 0v3"/><rect x="2.5" y="12" width="3.5" height="5" rx="1"/><rect x="14" y="12" width="3.5" height="5" rx="1"/>',
 bt:'<path d="m6 6 8 8-4 4V2l4 4-8 8"/>',
 plug:'<path d="M7 2v4M13 2v4M5 6h10v3a5 5 0 0 1-10 0zM10 14v4"/>',
 bolt:'<path d="M11 2 4 11h5l-1 7 7-9h-5z" fill="currentColor"/>'};
const svg=n=>`<svg width="16" height="16" viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${I[n]}</svg>`;
// SF Symbol de verdade (symbols.js / custom-symbols.js) quando existe, como máscara na cor do texto.
const sf=n=>{const s=SF[n];return `<i class="sf" style="width:${s.w/24}em;height:${s.h/24}em;-webkit-mask-image:url(${s.d});mask-image:url(${s.d})" aria-hidden="true"></i>`};
document.querySelectorAll('[data-i]').forEach(e=>e.innerHTML=typeof SF!=='undefined'&&SF[e.dataset.i]?sf(e.dataset.i):svg(e.dataset.i));
// Renderiza cada .pair em claro e escuro a partir de um único markup (protótipo, não vai para o app).
document.querySelectorAll('.pair').forEach(p=>{
  const html=p.innerHTML;
  p.innerHTML=['light','dark'].map(t=>`<div class="theme ${t}"><div style="width:100%"><p class="tag">${t==='light'?'Claro':'Escuro'}</p><div style="display:flex;gap:16px;flex-wrap:wrap;align-items:flex-start">${html}</div></div></div>`).join('');
});
