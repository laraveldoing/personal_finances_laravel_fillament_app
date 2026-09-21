# Next.js

Extends `base/*.md` and `languages/js-ts.md`. Only Next.js-specific additions below.

1. **Server vs Client components.** Default to Server Components; add `"use client"` only when
   the component genuinely needs interactivity, browser APIs, or hooks. Don't mark a component
   client-side "just in case."
2. **Data fetching** happens in Server Components/route handlers, not client-side `useEffect`
   fetches, unless the data is genuinely user-interaction-driven (e.g. live search).
3. **Routing**: use the App Router conventions already established in the project (`app/`
   directory structure, `layout.tsx`, `loading.tsx`, `error.tsx`) — don't mix Pages Router
   patterns into an App Router project or vice versa.
4. **Environment variables**: only prefix with `NEXT_PUBLIC_` if the value must be exposed to the
   browser. Never prefix secrets this way (see base rule on secrets).
5. **Images**: use `next/image` instead of raw `<img>` unless there's a documented reason not to
   (e.g. incompatible with a specific external CDN behavior).
6. **Metadata**: use the Metadata API (`generateMetadata` / static `metadata` export) rather than
   manually injecting `<head>` tags.
