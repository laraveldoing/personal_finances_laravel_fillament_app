# Nuxt.js

Extends `base/*.md` and `languages/js-ts.md`. Only Nuxt-specific additions below.

1. **Auto-imports**: rely on Nuxt's auto-import for components/composables under their
   conventional directories (`components/`, `composables/`) — don't add manual imports for things
   Nuxt already auto-imports, it adds noise and can mask duplicate naming.
2. **Composables over mixins.** Business logic reused across components goes in a composable
   (`composables/useX.ts`), never in a Vue mixin.
3. **Data fetching**: use `useFetch`/`useAsyncData` for SSR-aware data fetching, not raw
   client-only `fetch` in `onMounted`, unless the data is genuinely client-only/interaction-driven.
4. **Server routes**: use `server/api/` (Nitro) for backend logic colocated with the app rather
   than standing up a separate service, unless the project already has a separate backend.
5. **Runtime config**: use `useRuntimeConfig()` for anything environment-dependent; only expose
   values under the `public` key if they must reach the client (see base rule on secrets).
6. **Single-root components**: Vue components must have a single root element (consistent with
   the base Vue/Inertia convention if the project also uses Inertia elsewhere).
