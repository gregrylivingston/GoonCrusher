#include "goon_body.h"

#include "world_grid.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/kinematic_collision2d.hpp>
#include <godot_cpp/classes/sprite_frames.hpp>
#include <godot_cpp/classes/static_body2d.hpp>
#include <godot_cpp/classes/tile_map.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/core/object.hpp>

using namespace godot;

Rect2 GoonBody::physics_view;

// StringNames are made once the library is initialized and freed before it unloads (register_types.cpp)
namespace {
struct Names {
	StringName move = "move";
	StringName walk = "walk";
	StringName windup = "windup";
	StringName attack = "attack";
	StringName charge = "charge";
	StringName roll = "roll";
	StringName slam = "slam";
	StringName dive = "dive";
	StringName flee = "flee";
	StringName dodge = "dodge";
	StringName on_car_contact = "_onCarContact";
	StringName world_lethal_at = "_worldLethalAt";
	StringName world_slide_step = "_worldSlideStep";
};
Names *names = nullptr;
} // namespace

void GoonBody::init_names() {
	if (names == nullptr) {
		names = memnew(Names);
	}
}

void GoonBody::free_names() {
	if (names != nullptr) {
		memdelete(names);
		names = nullptr;
	}
}

static inline double now_seconds() {
	return Time::get_singleton()->get_ticks_msec() / 1000.0; // GoonVerbs.now()
}

void GoonBody::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_speed", "value"), &GoonBody::set_speed);
	ClassDB::bind_method(D_METHOD("get_speed"), &GoonBody::get_speed);
	ClassDB::bind_method(D_METHOD("set_turn_rate", "value"), &GoonBody::set_turn_rate);
	ClassDB::bind_method(D_METHOD("get_turn_rate"), &GoonBody::get_turn_rate);
	ClassDB::bind_method(D_METHOD("set_body_radius", "value"), &GoonBody::set_body_radius);
	ClassDB::bind_method(D_METHOD("get_body_radius"), &GoonBody::get_body_radius);
	ClassDB::bind_method(D_METHOD("set_buff_scale", "value"), &GoonBody::set_buff_scale);
	ClassDB::bind_method(D_METHOD("get_buff_scale"), &GoonBody::get_buff_scale);
	ClassDB::bind_method(D_METHOD("set_buff_until", "value"), &GoonBody::set_buff_until);
	ClassDB::bind_method(D_METHOD("get_buff_until"), &GoonBody::get_buff_until);
	ClassDB::bind_method(D_METHOD("set_state_name", "value"), &GoonBody::set_state_name);
	ClassDB::bind_method(D_METHOD("get_state_name"), &GoonBody::get_state_name);
	ClassDB::bind_method(D_METHOD("set_state_time", "value"), &GoonBody::set_state_time);
	ClassDB::bind_method(D_METHOD("get_state_time"), &GoonBody::get_state_time);
	ClassDB::bind_method(D_METHOD("set_cooldown", "value"), &GoonBody::set_cooldown);
	ClassDB::bind_method(D_METHOD("get_cooldown"), &GoonBody::get_cooldown);
	ClassDB::bind_method(D_METHOD("set_resist_timer", "value"), &GoonBody::set_resist_timer);
	ClassDB::bind_method(D_METHOD("get_resist_timer"), &GoonBody::get_resist_timer);
	ClassDB::bind_method(D_METHOD("set_stuck_time", "value"), &GoonBody::set_stuck_time);
	ClassDB::bind_method(D_METHOD("get_stuck_time"), &GoonBody::get_stuck_time);
	ClassDB::bind_method(D_METHOD("set_car_spin", "value"), &GoonBody::set_car_spin);
	ClassDB::bind_method(D_METHOD("get_car_spin"), &GoonBody::get_car_spin);
	ClassDB::bind_method(D_METHOD("set_last_car_rotation", "value"), &GoonBody::set_last_car_rotation);
	ClassDB::bind_method(D_METHOD("get_last_car_rotation"), &GoonBody::get_last_car_rotation);
	ClassDB::bind_method(D_METHOD("set_last_car_touch", "value"), &GoonBody::set_last_car_touch);
	ClassDB::bind_method(D_METHOD("get_last_car_touch"), &GoonBody::get_last_car_touch);
	ClassDB::bind_method(D_METHOD("set_lock_pos", "value"), &GoonBody::set_lock_pos);
	ClassDB::bind_method(D_METHOD("get_lock_pos"), &GoonBody::get_lock_pos);
	ClassDB::bind_method(D_METHOD("set_lock_dir", "value"), &GoonBody::set_lock_dir);
	ClassDB::bind_method(D_METHOD("get_lock_dir"), &GoonBody::get_lock_dir);
	ClassDB::bind_method(D_METHOD("set_my_mode", "value"), &GoonBody::set_my_mode);
	ClassDB::bind_method(D_METHOD("get_my_mode"), &GoonBody::get_my_mode);

	// runtime state: readable and writable from GDScript, never stored in a scene
	const uint32_t RUNTIME = PROPERTY_USAGE_NONE;
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "speed", PROPERTY_HINT_NONE, "", RUNTIME), "set_speed", "get_speed");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "turnRate", PROPERTY_HINT_NONE, "", RUNTIME), "set_turn_rate", "get_turn_rate");
	// set by the baked goon scenes (scripts/art/bake_goons.py)
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "bodyRadius"), "set_body_radius", "get_body_radius");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "buffScale", PROPERTY_HINT_NONE, "", RUNTIME), "set_buff_scale", "get_buff_scale");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "buffUntil", PROPERTY_HINT_NONE, "", RUNTIME), "set_buff_until", "get_buff_until");
	ADD_PROPERTY(PropertyInfo(Variant::STRING_NAME, "state", PROPERTY_HINT_NONE, "", RUNTIME), "set_state_name", "get_state_name");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "stateTime", PROPERTY_HINT_NONE, "", RUNTIME), "set_state_time", "get_state_time");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "cooldown", PROPERTY_HINT_NONE, "", RUNTIME), "set_cooldown", "get_cooldown");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "resistTimer", PROPERTY_HINT_NONE, "", RUNTIME), "set_resist_timer", "get_resist_timer");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "stuckTime", PROPERTY_HINT_NONE, "", RUNTIME), "set_stuck_time", "get_stuck_time");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "carSpin", PROPERTY_HINT_NONE, "", RUNTIME), "set_car_spin", "get_car_spin");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "lastCarRotation", PROPERTY_HINT_NONE, "", RUNTIME), "set_last_car_rotation", "get_last_car_rotation");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "lastCarTouch", PROPERTY_HINT_NONE, "", RUNTIME), "set_last_car_touch", "get_last_car_touch");
	ADD_PROPERTY(PropertyInfo(Variant::VECTOR2, "lockPos", PROPERTY_HINT_NONE, "", RUNTIME), "set_lock_pos", "get_lock_pos");
	ADD_PROPERTY(PropertyInfo(Variant::VECTOR2, "lockDir", PROPERTY_HINT_NONE, "", RUNTIME), "set_lock_dir", "get_lock_dir");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "myMode", PROPERTY_HINT_NONE, "", RUNTIME), "set_my_mode", "get_my_mode");

	ClassDB::bind_method(D_METHOD("bindSprite", "sprite"), &GoonBody::bind_sprite);
	ClassDB::bind_method(D_METHOD("beginTick", "delta", "car"), &GoonBody::begin_tick);
	ClassDB::bind_method(D_METHOD("tickTimers", "delta", "car"), &GoonBody::tick_timers);
	ClassDB::bind_method(D_METHOD("overDeepWater", "car"), &GoonBody::over_deep_water);
	ClassDB::bind_method(D_METHOD("touchedByCar"), &GoonBody::touched_by_car);

	ClassDB::bind_method(D_METHOD("speedNow"), &GoonBody::speed_now);
	ClassDB::bind_method(D_METHOD("isBuffed"), &GoonBody::is_buffed);
	ClassDB::bind_method(D_METHOD("distTo", "car"), &GoonBody::dist_to);
	ClassDB::bind_method(D_METHOD("setState", "state"), &GoonBody::set_state);
	ClassDB::bind_method(D_METHOD("play", "anim", "duration"), &GoonBody::play, DEFVAL(0.0));
	ClassDB::bind_method(D_METHOD("walkAnim", "moveSpeed"), &GoonBody::walk_anim);
	ClassDB::bind_method(D_METHOD("faceTo", "angle", "delta", "rate"), &GoonBody::face_to, DEFVAL(-1.0));
	ClassDB::bind_method(D_METHOD("chase", "target", "moveSpeed", "delta", "rate"), &GoonBody::chase, DEFVAL(-1.0));
	ClassDB::bind_method(D_METHOD("advance", "velocity", "delta"), &GoonBody::advance);
	ClassDB::bind_method(D_METHOD("predict", "car", "lead"), &GoonBody::predict);
	ClassDB::bind_method(D_METHOD("lockOn", "car", "lead"), &GoonBody::lock_on);

	ClassDB::bind_static_method("GoonBody", D_METHOD("setPhysicsView", "view"), &GoonBody::set_physics_view);
	ClassDB::bind_static_method("GoonBody", D_METHOD("getPhysicsView"), &GoonBody::get_physics_view);
	ClassDB::bind_static_method("GoonBody", D_METHOD("needsFullPhysics", "point"), &GoonBody::needs_full_physics);
}

GoonBody::GoonBody() {
	if (names != nullptr) {
		state = names->move;
	}
}

//--- the tick ----------------------------------------------------------------------------------------

void GoonBody::bind_sprite(AnimatedSprite2D *p_sprite) {
	sprite = p_sprite;
}

// The start of Walker's tick: the state clock, then (every WATER_TICKS ticks, staggered) the water check.
// True when the goon is over deep water and must drown.
bool GoonBody::begin_tick(double p_delta, Node2D *p_car) {
	car_id = p_car != nullptr ? ObjectID(p_car->get_instance_id()) : ObjectID();
	state_time += p_delta;
	const uint64_t phase = get_instance_id() % WATER_TICKS;
	return (Engine::get_singleton()->get_physics_frames() + phase) % WATER_TICKS == 0 && over_deep_water(p_car);
}

// Cooldowns and the car's turn rate (rad/s), after the lure check
void GoonBody::tick_timers(double p_delta, Node2D *p_car) {
	cooldown = MAX(0.0, cooldown - p_delta);
	resist_timer = MAX(0.0, resist_timer - p_delta);
	if (p_car == nullptr) {
		return;
	}
	const double rotation = p_car->get_rotation();
	car_spin = Math::angle_difference(last_car_rotation, rotation) / p_delta;
	last_car_rotation = rotation;
}

// Walker.checkWater without the drowning: a solid goon over deep water (the bumper alongside counts as a touch)
bool GoonBody::over_deep_water(Node2D *p_car) {
	if (get_collision_layer() == 0) {
		return false;
	}
	if (p_car != nullptr && dist_to(p_car) < body_radius * get_scale().x + TOUCH_REACH) {
		touched_by_car();
	}
	return lethal_here(get_global_position());
}

void GoonBody::touched_by_car() {
	last_car_touch = now_seconds();
}

bool GoonBody::lethal_here(const Vector2 &p_pos) {
	WorldGrid *grid = WorldGrid::current();
	if (grid != nullptr) {
		return grid->lethal_at(p_pos);
	}
	return call(names->world_lethal_at, p_pos);
}

//--- helpers -----------------------------------------------------------------------------------------

double GoonBody::speed_now() const {
	return speed * (is_buffed() ? buff_scale : 1.0);
}

bool GoonBody::is_buffed() const {
	return buff_until > now_seconds();
}

double GoonBody::dist_to(Node2D *p_car) const {
	return get_global_position().distance_to(p_car->get_global_position());
}

// State changes keep myMode in step for the AI driver
void GoonBody::set_state(const StringName &p_state) {
	state = p_state;
	state_time = 0.0;
	if (p_state == names->windup) {
		my_mode = PREPAREATTACK;
	} else if (p_state == names->attack || p_state == names->charge || p_state == names->roll || p_state == names->slam || p_state == names->dive) {
		my_mode = ATTACK;
	} else if (p_state == names->move || p_state == names->flee || p_state == names->dodge) {
		my_mode = MOVE;
	} else {
		my_mode = IDLE;
	}
}

// Plays an animation; a duration stretches it so its frames span that time
void GoonBody::play(const StringName &p_anim, double p_duration) {
	if (sprite == nullptr) {
		return;
	}
	if (sprite->get_animation() != p_anim || !sprite->is_playing()) {
		sprite->play(p_anim);
	}
	if (p_duration > 0.0) {
		Ref<SpriteFrames> frames = sprite->get_sprite_frames();
		sprite->set_speed_scale(frames->get_frame_count(p_anim) / frames->get_animation_speed(p_anim) / p_duration);
	} else {
		sprite->set_speed_scale(1.0);
	}
}

// The walk plays at the rate the goon covers ground, so feet never skate
void GoonBody::walk_anim(double p_move_speed) {
	if (sprite == nullptr) {
		return;
	}
	if (sprite->get_animation() != names->walk) {
		sprite->play(names->walk);
	}
	sprite->set_speed_scale(CLAMP(p_move_speed / (body_radius * WALK_CYCLE_PER_R * 10.0 / 8.0 * get_scale().x), 0.2, 3.0));
}

void GoonBody::face_to(double p_angle, double p_delta, double p_rate) {
	const double r = (p_rate < 0.0 ? turn_rate : p_rate) * p_delta;
	const double rotation = get_rotation();
	set_rotation(rotation + CLAMP(Math::angle_difference(rotation, p_angle), -r, r));
}

// Walks toward a point. Off screen it skips collision queries (the spawn manager's LOD)
void GoonBody::chase(const Vector2 &p_target, double p_move_speed, double p_delta, double p_rate) {
	face_to((p_target - get_global_position()).angle(), p_delta, p_rate);
	advance(Vector2::from_angle(get_rotation()) * p_move_speed, p_delta);
	walk_anim(p_move_speed);
}

void GoonBody::advance(const Vector2 &p_velocity, double p_delta) {
	set_velocity(p_velocity);
	const Vector2 position = get_global_position();
	if (!needs_full_physics(position)) {
		// off screen: no physics, the grid's walls and water
		const Vector2 step = p_velocity * p_delta;
		WorldGrid *grid = WorldGrid::current();
		set_global_position(grid != nullptr ? grid->slide_step(position, step) : (Vector2)call(names->world_slide_step, position, step));
		return;
	}
	move_and_slide();
	// the car takes contact damage every tick it touches a goon, so goons that bump it step back off
	Object *car = ObjectDB::get_instance(car_id);
	bool pressing = false;
	const int count = get_slide_collision_count();
	for (int i = 0; i < count; i++) {
		Ref<KinematicCollision2D> hit = get_slide_collision(i);
		Object *collider = hit.is_valid() ? hit->get_collider() : nullptr;
		if (collider == nullptr) {
			continue;
		}
		if (collider == car) {
			touched_by_car();
			stuck_time = 0.0;
			call(names->on_car_contact, car);
			return;
		}
		// World.isWall
		if (Object::cast_to<StaticBody2D>(collider) != nullptr || Object::cast_to<TileMap>(collider) != nullptr) {
			pressing = true;
		}
	}
	// walking into a barrier and getting nowhere: after WorldHooks.STUCK_SECONDS the despawn sweep may take it
	if (pressing && get_real_velocity().length() < p_velocity.length() * 0.3) {
		stuck_time += p_delta;
	} else {
		stuck_time = MAX(0.0, stuck_time - p_delta * 2.0);
	}
}

// Where the car will be in `lead` seconds
Vector2 GoonBody::predict(Node2D *p_car, double p_lead) const {
	CharacterBody2D *body = Object::cast_to<CharacterBody2D>(p_car);
	const Vector2 velocity = body != nullptr ? body->get_velocity() : (Vector2)p_car->get("velocity");
	return p_car->get_global_position() + velocity * p_lead;
}

void GoonBody::lock_on(Node2D *p_car, double p_lead) {
	lock_pos = predict(p_car, p_lead);
	lock_dir = (lock_pos - get_global_position()).normalized();
}

//--- the LOD view ------------------------------------------------------------------------------------

void GoonBody::set_physics_view(const Rect2 &p_view) {
	physics_view = p_view;
}

Rect2 GoonBody::get_physics_view() {
	return physics_view;
}

bool GoonBody::needs_full_physics(const Vector2 &p_point) {
	return !physics_view.has_area() || physics_view.has_point(p_point);
}
