# Flujo de Trabajo para Frontend
1. Antes de escribir CSS, inspeccionar el elemento en el navegador y anotar las clases `fi-*` relevantes.
2. Si el cambio afecta a múltiples elementos o es global, crear/editar el tema personalizado en `resources/css/filament/nombre-tema.css`.
3. Si el cambio es un componente nuevo, crear un componente de Blade en `resources/views/components/`.
4. Nunca usar `!important` a menos que sea estrictamente necesario y esté justificado.
5. Después de un cambio, ejecutar `npm run dev` o `npm run build` y verificar en el navegador.
