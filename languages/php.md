# PHP

Extends `base/*.md`. Only PHP-specific additions below.

1. Always use curly braces for control structures, even for single-line bodies.
2. Use constructor property promotion (PHP 8+):
   `public function __construct(public GitHub $github) { }`.
   Do not leave empty zero-parameter `__construct()` methods unless the constructor is private.
3. Use explicit return type declarations and type hints for all method parameters:
   `function isAccessible(User $user, ?string $path = null): bool`.
4. Use TitleCase for Enum keys: `FavoritePerson`, `BestLake`, `Monthly`.
5. Prefer PHPDoc blocks over inline comments. Only add inline comments for exceptionally complex
   logic.
6. Use array shape type definitions in PHPDoc blocks for complex array structures.
