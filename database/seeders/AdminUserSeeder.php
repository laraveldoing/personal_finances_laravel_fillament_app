<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use RuntimeException;

class AdminUserSeeder extends Seeder
{
    /**
     * Create (or update) the single administrator the Filament panel logs in.
     *
     * Idempotent by email: running it twice leaves exactly one row. A soft-deleted row is restored
     * rather than duplicated — a soft-deleted user keeps its email, so a plain `updateOrCreate()`
     * would collide with the unique index instead of finding the row
     * (see `/plans/user-delete-policy.md`, decision D20).
     */
    public function run(): void
    {
        $name = config('filament-admin.name');
        $email = config('filament-admin.email');
        $password = config('filament-admin.password');

        $missing = collect([
            'FILAMENT_ADMIN_NAME' => $name,
            'FILAMENT_ADMIN_EMAIL' => $email,
            'FILAMENT_ADMIN_PASSWORD' => $password,
        ])
            ->filter(fn ($value) => blank($value))
            ->keys();

        if ($missing->isNotEmpty()) {
            throw new RuntimeException(
                'Missing environment variable(s) in .env: '.$missing->implode(', ').
                ' — the admin user was not seeded.'
            );
        }

        $user = User::withTrashed()->firstOrNew(['email' => $email]);

        if ($user->trashed()) {
            $user->restore();
        }

        $user->fill(['name' => $name, 'password' => $password])->save();
    }
}
