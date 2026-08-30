// Arcane Dark site interactions
document.addEventListener('DOMContentLoaded', () => {
  const reveals = document.querySelectorAll('.reveal');
  const io = new IntersectionObserver((entries) => {
    entries.forEach(e => {
      if(e.isIntersecting){ e.target.classList.add('in'); io.unobserve(e.target); }
    });
  }, {threshold: 0.12});
  reveals.forEach(el => io.observe(el));

  // Lightbox
  const lb = document.getElementById('lightbox');
  const lbImg = document.getElementById('lightbox-img');
  const lbTitle = document.getElementById('lightbox-title');
  const lbClose = document.getElementById('lightbox-close');
  function openLightbox(src, title){
    if(!lb) return;
    lbImg.src = src;
    lbTitle.textContent = title || '';
    lb.classList.add('open');
    document.body.style.overflow = 'hidden';
  }
  function closeLightbox(){
    if(!lb) return;
    lb.classList.remove('open');
    document.body.style.overflow = '';
  }
  document.querySelectorAll('[data-lightbox]').forEach(a=>{
    a.addEventListener('click', (e)=>{
      e.preventDefault();
      openLightbox(a.getAttribute('href') || a.querySelector('img')?.src, a.dataset.title || '');
    });
  });
  lb?.addEventListener('click', (e)=>{ if(e.target===lb) closeLightbox(); });
  lbClose?.addEventListener('click', closeLightbox);
  document.addEventListener('keydown', (e)=>{ if(e.key==='Escape') closeLightbox(); });

  // Smooth scroll offset for sticky nav
  document.querySelectorAll('a[href^="#"]').forEach(a=>{
    a.addEventListener('click', e=>{
      const id = a.getAttribute('href');
      if(!id || id==='#') return;
      const target = document.querySelector(id);
      if(target){
        e.preventDefault();
        const top = target.getBoundingClientRect().top + window.scrollY - 72;
        window.scrollTo({top, behavior:'smooth'});
      }
    });
  });
});
