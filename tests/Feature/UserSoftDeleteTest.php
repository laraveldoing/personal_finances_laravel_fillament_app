<?php

namespace Tests\Feature;

use App\Models\User;
use Database\Seeders\AdminUserSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Auth;
use Tests\TestCase;

class UserSoftDeleteTest extends TestCase
{
    use RefreshDatabase;

    public function test_an_active_user_can_authenticate(): void
    {
        $user = User::factory()->create(['password' => 'correct-password']);

        $this->assertTrue(Auth::attempt([
            'email' => $user->email,
            'password' => 'correct-password',
        ]));
    }

    public function test_a_soft_deleted_user_keeps_its_row_and_stops_authenticating(): void
    {
        $user = User::factory()->create(['password' => 'correct-password']);

        $user->delete();

        $this->assertSoftDeleted($user);
        $this->assertDatabaseHas('users', ['email' => $user->email]);
        $this->assertNull(User::find($user->id));
        $this->assertFalse(Auth::attempt([
            'email' => $user->email,
            'password' => 'correct-password',
        ]));
    }

    public function test_the_admin_seeder_restores_a_soft_deleted_admin_instead_of_duplicating(): void
    {
        config([
            'filament-admin.name' => 'Test Admin',
            'filament-admin.email' => 'admin@example.test',
            'filament-admin.password' => 'seeded-password',
        ]);

        $this->seed(AdminUserSeeder::class);
        User::where('email', 'admin@example.test')->firstOrFail()->delete();

        $this->seed(AdminUserSeeder::class);

        $admin = User::where('email', 'admin@example.test')->firstOrFail();

        $this->assertFalse($admin->trashed());
        $this->assertSame(1, User::withTrashed()->where('email', 'admin@example.test')->count());
        $this->assertTrue(Auth::attempt([
            'email' => 'admin@example.test',
            'password' => 'seeded-password',
        ]));
    }
}
