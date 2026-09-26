# Contexto del Proyecto
- Framework: Laravel 13 + Filament v5.
- Frontend del panel: Filament v5. NO modificar directamente los archivos en `vendor/`.
- Estilos: Usar CSS Hooks (clases `fi-*`) y variables CSS de Filament.
- Temas: Cualquier cambio de estilo global debe hacerse en un tema personalizado en `resources/css/filament/`.
- Vistas Blade: No publicar ni editar vistas de Filament a menos que sea estrictamente necesario. Si se necesita, publicar solo las vistas específicas con `php artisan vendor:publish --tag="filament-views"` y modificar solo esas.
- Componentes personalizados: Preferir crear componentes de Blade personalizados en `resources/views/components/` y usarlos con `<x-...>` en lugar de sobrescribir componentes de Filament.
