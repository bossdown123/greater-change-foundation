import { useEffect, useRef, useState } from 'react'
import { ArrowDown, ArrowLeft, ArrowUpRight, Mail, Menu, Search, X, Plus } from 'lucide-react'
import {PhotoViewer} from '../components/photo-viewer'
import { contactEmail, galleryPhotos, galleryThumbnail, imagePath, mission, pageMeta, stories, storyPath, type Photograph, type Story } from './content'
import './public-site.css'
import dimensions from './photo-dimensions.json'

const links = [['/our-work', 'Our work'], ['/updates', 'Updates'], ['/about', 'About us'], ['/support', 'Get involved']]
const mailto = (subject = 'Hello, Greater Change Foundation') => `mailto:${contactEmail}?subject=${encodeURIComponent(subject)}`
function Picture({ photo, eager = false, className = '' }: { photo: Photograph; eager?: boolean; className?: string }) {
 const [width,height] = (dimensions as Record<string,number[]>)[photo.file]
 return <img className={className} src={imagePath(photo)} srcSet={`${imagePath(photo, true)} 800w, ${imagePath(photo)} 1600w`} sizes="(max-width: 700px) 100vw, (max-width: 1100px) 70vw, 850px" alt={photo.alt} loading={eager ? 'eager' : 'lazy'} fetchPriority={eager ? 'high' : 'auto'} decoding="async" width={width} height={height} />
}
function TextLink({ href, children, light = false }: { href: string; children: React.ReactNode; light?: boolean }) {
 return <a className={`gcf-text-link${light ? ' light' : ''}`} href={href}>{children}<ArrowUpRight size={20} aria-hidden="true" /></a>
}
function Header({ path }: { path: string }) {
 const [open, setOpen] = useState(false)
 return <header className="gcf-header">
  <a className="gcf-brand" href="/" aria-label="Greater Change Foundation home"><img src="/assets/gcf-mark.webp" width="64" height="64" alt="" /><span>Greater Change<small>Foundation</small></span></a>
  <button type="button" className="gcf-menu-toggle" aria-expanded={open} aria-controls="gcf-navigation" onClick={() => setOpen(!open)}>{open ? <X size={22}/> : <Menu size={22}/>}<span>{open ? 'Close' : 'Menu'}</span></button>
  <nav id="gcf-navigation" className={open ? 'is-open' : ''} aria-label="Main navigation">{links.map(([href, label]) => <a key={href} href={href} aria-current={path === href || (href === '/our-work' && path.startsWith('/our-work/')) ? 'page' : undefined} className={href === '/support' ? 'gcf-nav-action' : ''}>{label}{href === '/support' && <ArrowUpRight size={17} aria-hidden="true"/>}</a>)}</nav>
 </header>
}
function Footer() {
 return <footer className="gcf-footer">
  <a className="gcf-footer-wordmark" href="/">Greater Change<br/><em>starts with us.</em></a>
  <div><span className="gcf-eyebrow">Say hello</span><a className="gcf-email" href={mailto()}>{contactEmail}<ArrowUpRight size={18} aria-hidden="true"/></a></div>
  <nav aria-label="Footer">{links.map(([href,label]) => <a href={href} key={href}>{label}</a>)}</nav>
  <div className="gcf-footer-base"><span>© {new Date().getFullYear()} Greater Change Foundation</span><a href="/privacy">Privacy</a><a href="/admin">Member sign in<ArrowUpRight size={14} aria-hidden="true"/></a></div>
 </footer>
}
function Invitation() {
 return <section className="gcf-invitation"><span className="gcf-eyebrow">There’s a place for you here</span><h2>Bring what you can.<br/><em>Be part of what’s next.</em></h2><a href="/support" className="gcf-round-link" aria-label="Get involved with GCF"><ArrowUpRight aria-hidden="true"/></a><p>Good things begin with people coming together.</p><TextLink href="/support">Get involved</TextLink></section>
}
function StoryRow({ story }: { story: Story }) {
 return <a className="gcf-story-row" href={storyPath(story)}><span className="gcf-story-date">{story.year}<small>{story.category}</small></span><h3>{story.title}</h3><p>{story.intro}</p><ArrowUpRight aria-hidden="true"/></a>
}
function Home() {
 return <>
  <section className="gcf-hero">
   <div className="gcf-hero-copy"><span className="gcf-eyebrow">People. Purpose. Possibility.</span><h1>Small acts.<br/>Greater <em>change.</em></h1><p>When we show up for each other, something greater begins.</p><a className="gcf-button" href="/our-work">Discover our work<ArrowUpRight size={20} aria-hidden="true"/></a><a href="#our-purpose" className="gcf-down" aria-label="Explore our purpose"><ArrowDown size={20} aria-hidden="true"/></a></div>
   <figure className="gcf-hero-image"><Picture photo={stories[0].photos[0]} eager/><figcaption>In good company. Child’s Month, 2025.</figcaption><span className="gcf-sun" aria-hidden="true"><svg viewBox="0 0 100 100"><path d="M50 5v17m0 56v17M5 50h17m56 0h17M18 18l12 12m40 40 12 12M18 82l12-12m40-40 12-12"/><circle cx="50" cy="50" r="20"/></svg></span></figure>
  </section>
  <section id="our-purpose" className="gcf-purpose"><span className="gcf-eyebrow">The Greater Change Foundation</span><h2>Care is a small word.<br/><em>It can mean so much.</em></h2><div><p>{mission}</p><p>Through community activities, shared meals and moments of connection, GCF brings people together around that purpose.</p><TextLink href="/about">Meet the foundation</TextLink></div></section>
  <section className="gcf-feature"><a href={storyPath(stories[2])} aria-label="Read More than a shared meal"><Picture photo={stories[2].photos[0]}/></a><div><span className="gcf-eyebrow">Community · Christmas 2023</span><h2>More than<br/><em>a shared meal.</em></h2><p>The Christmas table starts with many hands. A glimpse of the care and preparation behind GCF’s Christmas initiative.</p><TextLink href={storyPath(stories[2])}>See the story</TextLink></div></section>
  <section className="gcf-journal"><header><span className="gcf-eyebrow">From the community</span><h2>People make<br/><em>the difference.</em></h2><TextLink href="/updates">All updates</TextLink></header>{stories.slice(0,3).map(story => <StoryRow key={story.slug} story={story}/>)}</section>
  <Invitation/>
 </>
}
function Work() {
 const [filter,setFilter] = useState('All'), [query,setQuery] = useState('')
 const filtered = stories.filter(s => (filter === 'All' || s.category === filter) && `${s.title} ${s.intro} ${s.year}`.toLowerCase().includes(query.toLowerCase()))
 return <>
  <section className="gcf-page-intro"><span className="gcf-eyebrow">Our work</span><h1>Care in action.<br/><em>People at the heart.</em></h1><p>Explore moments from GCF’s community activities, gatherings and outreach.</p></section>
  <section className="gcf-work" aria-label="Explore our work"><div className="gcf-work-tools"><div className="gcf-filters" role="group" aria-label="Filter work">{['All','Community','Children','Health','Together'].map(item => <button key={item} type="button" aria-pressed={filter === item} onClick={() => setFilter(item)}>{item}</button>)}</div><label className="gcf-search"><Search size={18} aria-hidden="true"/><input type="search" aria-label="Search our work" placeholder="Find a story" value={query} onChange={e => setQuery(e.target.value)}/></label></div>
   <span className="gcf-sr-only" role="status">{filtered.length} {filtered.length === 1 ? 'story' : 'stories'}</span>
   {filtered.map((story,index) => <article className="gcf-work-story" key={story.slug}><a href={storyPath(story)} className="gcf-work-image" aria-label={story.title}><Picture photo={story.photos[0]} eager={index === 0}/><span aria-hidden="true"><ArrowUpRight/></span></a><div><span className="gcf-eyebrow">{story.category} · {story.year}</span><h2><a href={storyPath(story)}>{story.title}</a></h2><p>{story.intro}</p><TextLink href={storyPath(story)}>Explore the story</TextLink></div></article>)}
   {!filtered.length && <p className="gcf-no-results">No stories match “{query}”. <button type="button" onClick={() => {setQuery('');setFilter('All')}}>Clear filters</button></p>}
  </section><Invitation/>
 </>
}
function Updates() {
 return <><section className="gcf-page-intro"><span className="gcf-eyebrow">Updates</span><h1>Moments worth<br/><em>coming back to.</em></h1><p>Photographs and stories from the GCF community.</p></section><section className="gcf-updates" aria-label="Community stories">{stories.map(story => <article key={story.slug}><a href={storyPath(story)} className="gcf-update-image" aria-label={story.title}><Picture photo={story.photos[0]}/></a><StoryRow story={story}/></article>)}</section><Invitation/></>
}
function StoryPage({ story, initiallyOpen = false }: { story: Story; initiallyOpen?: boolean }) {
 const [open,setOpen]=useState(false),opener=useRef<HTMLAnchorElement|null>(null),pushed=useRef(false)
 const galleryPath=`/galleries/${story.slug}`, articlePath=storyPath(story),photos=galleryPhotos(story)
 useEffect(()=>{setOpen(initiallyOpen);const pop=()=>{setOpen(location.pathname===galleryPath);document.title=pageMeta(location.pathname).title};window.addEventListener('popstate',pop);return()=>window.removeEventListener('popstate',pop)},[initiallyOpen,galleryPath])
 function show(value:boolean){setOpen(value);if(value){if(location.pathname!==galleryPath){history.pushState(null,'',galleryPath);pushed.current=true}}else if(pushed.current&&location.pathname===galleryPath){pushed.current=false;history.back()}else history.replaceState(null,'',articlePath);document.title=pageMeta(value?galleryPath:articlePath).title}

 const next = stories[(stories.indexOf(story)+1)%stories.length]
 return <><article className="gcf-story"><header className="gcf-page-intro"><a className="gcf-back" href="/our-work"><ArrowLeft size={17} aria-hidden="true"/>Our work</a><span className="gcf-eyebrow">{story.category} · {story.year}</span><h1>{story.title}</h1><p>{story.intro}</p></header><figure className="gcf-story-cover"><Picture photo={story.photos[0]} eager/><figcaption>{story.photos[0].caption}</figcaption></figure><div className="gcf-story-prose">{story.paragraphs.map(p => <p key={p}>{p}</p>)}</div>{story.photos[1]&&<figure className="gcf-article-photo"><Picture photo={story.photos[1]}/><figcaption>{story.photos[1].caption}</figcaption></figure>}<section className="gcf-gallery-link"><span className="gcf-eyebrow">{photos.length} photographs</span><h2>A closer look.</h2><a ref={opener} className="gcf-button" href={galleryPath} onClick={event=>{event.preventDefault();show(true)}}>Open gallery<ArrowUpRight size={20} aria-hidden="true"/></a></section><PhotoViewer open={open} onOpenChange={show} title={story.title} photos={photos.map(photo=>({id:photo.file,src:imagePath(photo),thumbnail:galleryThumbnail(photo),alt:photo.alt,caption:photo.caption}))} returnFocus={()=>opener.current?.focus({preventScroll:true})}/></article><aside className="gcf-next-story"><span className="gcf-eyebrow">Another moment from GCF</span><a href={storyPath(next)}><h2>{next.title}</h2><ArrowUpRight aria-hidden="true"/></a></aside><Invitation/></>
}
function Leadership() {
 return <section className="gcf-leadership" aria-labelledby="gcf-leader-name">
  <header><span className="gcf-eyebrow">Meet our chairman</span><h2 id="gcf-leader-name">Warner<br/><em>Bernard.</em></h2><p className="gcf-leader-role">Chairman of the Board</p><p>Warner Bernard chairs the Greater Change Foundation, helping bring people and partners together in support of children across Jamaica.</p><p>His work with the foundation includes building partnerships that support education and create opportunities for children and their communities.</p></header>
  <figure className="gcf-leader-photo"><Picture photo={{file: 'christmas-delivery', alt: 'Warner Bernard during GCF’s Christmas initiative, 2022.', caption: ''}}/></figure>
  <aside className="gcf-leader-statement" aria-labelledby="gcf-statement-label"><span id="gcf-statement-label" className="gcf-eyebrow">A note from Warner · coming soon</span><p className="gcf-statement-placeholder">Lorem ipsum dolor sit amet, consectetur adipiscing elit. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.</p><footer><p className="gcf-signature">Warner Bernard</p><small>Placeholder text · awaiting Warner’s own words</small></footer></aside>
 </section>
}
function About() {
 return <><section className="gcf-page-intro"><span className="gcf-eyebrow">About us</span><h1>A shared purpose.<br/><em>A greater change.</em></h1><p>We believe in the difference people can make for one another.</p></section><figure className="gcf-about-photo"><Picture photo={stories[2].photos[1]} eager/><figcaption>The people behind GCF’s Christmas initiative, 2023.</figcaption></figure><section className="gcf-purpose gcf-about-purpose"><span className="gcf-eyebrow">Our purpose</span><h2>A deeper appreciation<br/><em>for life itself.</em></h2><div><p>{mission}</p><p>You can see that purpose in the work: supplies being packed, a meal being prepared, people gathering for a blood drive, and a day made special for children.</p><p>It is the people behind these moments who give the Greater Change Foundation its meaning.</p><TextLink href="/our-work">Get to know our work</TextLink></div></section><Leadership/><section className="gcf-about-strip"><Picture photo={stories[3].photos[3]}/><div><span className="gcf-eyebrow">Together is where it starts</span><h2>Every contribution<br/><em>begins with a person.</em></h2><p>Want to get to know GCF, ask about our work or explore how you could help? We’d love to hear from you.</p><TextLink href="/support">Start a conversation</TextLink></div></section><Invitation/></>
}
function Support() {
 return <><section className="gcf-page-intro gcf-support-intro"><span className="gcf-eyebrow">Get involved</span><h1>There’s more we<br/>can do <em>together.</em></h1><p>A little time, a useful skill, a shared idea. Start a conversation about what you could bring to GCF.</p><a className="gcf-button" href={mailto('Getting involved with GCF')}>Say hello<Mail size={18} aria-hidden="true"/></a></section><section className="gcf-support-options"><span className="gcf-eyebrow">Start here</span><div><h2>Time & skills</h2><p>Tell us what you enjoy doing and how you’d like to contribute. Ask the team about opportunities to take part.</p><TextLink href={mailto('Sharing my time and skills with GCF')}>Talk to us</TextLink></div><div><h2>Working together</h2><p>Have an idea for a community activity or a collaboration? We’d love to hear what you have in mind.</p><TextLink href={mailto('An idea for working with GCF')}>Share an idea</TextLink></div><div><h2>Giving support</h2><p>Contact GCF directly to ask about current needs and how best to make a contribution.</p><TextLink href={mailto('Supporting the Greater Change Foundation')}>Ask about contributing</TextLink></div></section><figure className="gcf-support-photo"><Picture photo={stories[2].photos[3]}/><figcaption>Care in the preparation. Christmas initiative, 2023.</figcaption></figure><section className="gcf-contact"><span className="gcf-eyebrow">Contact GCF</span><h2>Good things start<br/><em>with a hello.</em></h2><a href={mailto()}>{contactEmail}<ArrowUpRight aria-hidden="true"/></a><p>Your email will open in your email app.</p></section></>
}
function Privacy() {
 return <section className="gcf-legal"><span className="gcf-eyebrow">Privacy</span><h1>A little clarity.</h1><h2>Browsing this website</h2><p>The public website does not use advertising cookies, third-party analytics or visitor accounts. Our server processes basic connection information to deliver pages and keep the service working.</p><h2>Getting in touch</h2><p>Contact links open your own email app. If you email GCF, the information you choose to send is handled through GCF’s email service. Please avoid sending sensitive personal information in an initial enquiry.</p><h2>Photographs</h2><p>This website includes photographs from GCF’s activities. To ask about a photograph or request that it be removed, email <a href={mailto('Website photograph enquiry')}>{contactEmail}</a> and include the page address.</p><h2>Member access</h2><p>The private member workspace uses essential sign-in cookies. Public visitors do not need to sign in to read the website.</p></section>
}
export function PublicSite({ path }: { path: string }) {
 const normalized = path !== '/' ? path.replace(/\/$/,'') : path
 const story = stories.find(item => storyPath(item) === normalized || `/galleries/${item.slug}` === normalized)
 useEffect(() => { document.title = pageMeta(normalized).title }, [normalized])
 return <div className="gcf-public"><a className="gcf-skip" href="#main-content">Skip to content</a><Header path={normalized.startsWith("/galleries/")&&story?storyPath(story):normalized}/><main id="main-content">{normalized === '/' ? <Home/> : normalized === '/our-work' ? <Work/> : normalized === '/updates' ? <Updates/> : normalized === '/about' ? <About/> : normalized === '/support' ? <Support/> : normalized === '/privacy' ? <Privacy/> : story ? (normalized.startsWith("/galleries/") ? <StoryPage story={story} initiallyOpen/> : <StoryPage story={story}/>) : <section className="gcf-page-intro"><span className="gcf-eyebrow">404</span><h1>A different path.</h1><p>We couldn’t find that page.</p><TextLink href="/">Return home</TextLink></section>}</main><Footer/></div>
}
