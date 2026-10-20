import React from "react"
import ReactDOM from "react-dom/client"
import { Badge } from "@/components/ui/badge"
import "./index.css"
const Admin = React.lazy(() => import("./admin").then(module => ({default: module.Admin})))

function App() {
  return (
    <main className="flex min-h-svh flex-col items-center justify-center gap-6 px-6 text-center">
      <h1 className="text-[clamp(5rem,18vw,11rem)] leading-none font-semibold tracking-[-0.08em]">GCF</h1>
      <Badge variant="outline" className="rounded-full px-5 py-2 text-[0.65rem] font-medium tracking-[0.24em]">UNDER DEVELOPMENT</Badge>
    </main>
  )
}
ReactDOM.createRoot(document.getElementById("root")!).render(<React.StrictMode>{window.location.pathname.startsWith("/admin") ? <React.Suspense fallback={<main aria-busy="true" aria-label="Opening workspace" />}><Admin /></React.Suspense> : <App />}</React.StrictMode>)
