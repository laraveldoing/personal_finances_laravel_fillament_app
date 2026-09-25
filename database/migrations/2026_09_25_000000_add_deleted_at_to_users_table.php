<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Add `deleted_at` to `users` so the framework's user table can be soft-deleted.
     *
     * `users` belongs to the migrations, not to `database/schema/01-personal-finances.sql` (whose
     * `users` block is an `IF NOT EXISTS` no-op), which is why the column is added here. See
     * `/plans/user-delete-policy.md` (D20): with the four `fk_*_user` constraints set to RESTRICT,
     * a soft delete is the only supported way to remove a user without a deliberate purge path.
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->softDeletes();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropSoftDeletes();
        });
    }
};
