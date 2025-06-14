-- ----------------------------
-- Enums & Extensions
-- ----------------------------
CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TYPE enum_gender AS ENUM ('male', 'female', 'unknown');
CREATE TYPE enum_employees_status AS ENUM ('active', 'resigned', 'probation', 'retired');
CREATE TYPE enum_room_status AS ENUM ('available','maintenance','disabled','reserved');
CREATE TYPE enum_rsvp_status AS ENUM ('accepted', 'declined', 'tentative', 'pending');

-- ----------------------------
-- Core Tables
-- ----------------------------
CREATE TABLE departments (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    parent_department_id INTEGER REFERENCES departments(id) -- NULL means it's a top-level department
);

CREATE TABLE positions (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL
);

CREATE TABLE employees (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    gender enum_gender,
    department_id INTEGER REFERENCES departments(id),
    position_id INTEGER REFERENCES positions(id),
    phone VARCHAR(20) UNIQUE,
    email VARCHAR(50) UNIQUE NOT NULL,
    hire_date DATE NOT NULL,
    leave_date DATE,
    status enum_employees_status NOT NULL DEFAULT 'probation'
);

CREATE TABLE regions (
    id SERIAL PRIMARY KEY, -- Use a meaningless auto-increment ID as a stable internal primary key
    code VARCHAR(50) UNIQUE, -- Store official and heterogeneous administrative codes (e.g., '110108', '90210', 'SW1A 0AA')
    name VARCHAR(100) NOT NULL,
    parent_id INTEGER REFERENCES regions(id), -- Self-referencing foreign key to build a global hierarchy tree
    level SMALLINT NOT NULL CHECK (level >= 0) -- 0:Global, 1:Country, 2:Province/State, etc.
);
COMMENT ON TABLE regions IS 'A unified, hierarchical table for all administrative and geographical areas, worldwide.';

CREATE TABLE office_areas(
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    region_id INTEGER NOT NULL REFERENCES regions(id),
    street_address VARCHAR(255) NOT NULL,
    geom GEOGRAPHY(Point, 4326) NOT NULL
);

CREATE TABLE rooms(
    id SERIAL PRIMARY KEY,
    office_area_id INTEGER NOT NULL REFERENCES office_areas(id),
    room_number VARCHAR(10) UNIQUE NOT NULL,
    name VARCHAR(50) NOT NULL,
    floor smallint NOT NULL,
    capacity smallint NOT NULL,
    status enum_room_status NOT NULL DEFAULT 'available',
    has_projector BOOLEAN NOT NULL DEFAULT false,
    has_whiteboard BOOLEAN NOT NULL DEFAULT false,
    has_video_conference BOOLEAN NOT NULL DEFAULT false,
    description TEXT
);

CREATE TABLE meetings (
    id SERIAL PRIMARY KEY,
    booking_number char(9) UNIQUE NOT NULL,
    title VARCHAR(50) NOT NULL,
    room_id INTEGER NOT NULL REFERENCES rooms(id),
    organizer_id INTEGER REFERENCES employees(id),
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    is_canceled BOOLEAN NOT NULL DEFAULT false,
    description TEXT,
    CONSTRAINT time_logic_check CHECK (end_time > start_time)
);

-- ----------------------------
-- Junction Table
-- ----------------------------
CREATE TABLE meeting_participants (
    meeting_id INTEGER REFERENCES meetings(id) ON DELETE CASCADE,
    employee_id INTEGER REFERENCES employees(id) ON DELETE CASCADE,
    rsvp_status enum_rsvp_status NOT NULL DEFAULT 'pending',
    PRIMARY KEY (meeting_id, employee_id) 
);

-- ----------------------------
-- Indexes for performance
-- ----------------------------
CREATE INDEX idx_regions_parent_id ON regions (parent_id);
CREATE INDEX idx_office_areas_region_id ON office_areas (region_id);
CREATE INDEX idx_rooms_office_area_id ON rooms (office_area_id);
CREATE INDEX idx_meetings_time ON meetings (room_id, start_time, end_time);
CREATE INDEX idx_meeting_participants_employee ON meeting_participants (employee_id);
