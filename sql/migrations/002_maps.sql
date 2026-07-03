-- 002_maps.sql
-- Add whimsical map storage for world + local views.
-- Maps are memorialized here so the current playthrough always has the version
-- of the art that existed when it was explored / generated.

CREATE TABLE IF NOT EXISTS maps (
    map_key VARCHAR(100) PRIMARY KEY,
    title VARCHAR(150) NOT NULL,
    ascii TEXT NOT NULL,
    map_type ENUM('world','local') DEFAULT 'local',
    related_location VARCHAR(100) NULL,   -- matches locations.key_name when applicable
    revealed BOOLEAN DEFAULT TRUE,
    notes TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Note: actual ASCII content is populated via seeds (or loader) so it can be
-- updated idempotently when we improve the art. See sql/seeds/001_initial_state.sql
-- and the maps/ directory for the human-readable source files.