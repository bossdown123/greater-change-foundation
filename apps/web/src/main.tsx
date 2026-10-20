import React from 'react'
import ReactDOM from 'react-dom/client'
import { PublicSite } from './public-site/public-site'
import './index.css'

const Admin = React.lazy(() => import('./admin').then(module => ({ default: module.Admin })))
const root = document.getElementById('root')!
const isAdmin = window.location.pathname.startsWith('/admin')
const app = isAdmin ? <React.Suspense fallback={<main aria-busy="true" aria-label="Opening workspace" />}><Admin /></React.Suspense> : <PublicSite path={window.location.pathname}/>
if (!isAdmin && root.hasChildNodes()) ReactDOM.hydrateRoot(root, <React.StrictMode>{app}</React.StrictMode>)
else ReactDOM.createRoot(root).render(<React.StrictMode>{app}</React.StrictMode>)
