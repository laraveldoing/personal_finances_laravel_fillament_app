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
     * Idempotent by email: running it twice leaves exactly one row.
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

        User::updateOrCreate(
            ['email' => $email],
            ['name' => $name, 'password' => $password],
        );
    }
}
