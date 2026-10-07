#pragma once

#include <godot_cpp/classes/animated_sprite2d.hpp>
#include <godot_cpp/classes/character_body2d.hpp>
#include <godot_cpp/variant/rect2.hpp>
#include <godot_cpp/variant/string_name.hpp>

namespace godot {

// The native half of every goon (scene/enemy/walker/walker.gd extends Enemy extends GoonBody; docs/GOONS.md,
// docs/NATIVE.md). It holds the fields the per-tick code reads and the movement helpers the verbs call
// (chase, advance, faceTo, play...), so a verb's call does its work here instead of in a chain of GDScript
// calls. The rules are the GDScript ones, moved as they were. GDScript keeps everything else: the verbs,
// damage, death, siege, lures. It is called back only for rare events (_onCarContact) and, when no native
// WorldGrid is current (test stand-ins), for the world queries (_worldLethalAt, _worldSlideStep).
class GoonBody : public CharacterBody2D {
	GDCLASS(GoonBody, CharacterBody2D)

	// Walker.mode
	enum Mode { MOVE, ATTACK, IDLE, DEAD, PREPAREATTACK };

	double speed = 110.0;
	double turn_rate = 9.0;
	double body_radius = 18.0;
	double buff_scale = 1.0;
	double buff_until = 0.0;
	StringName state;
	double state_time = 0.0;
	double cooldown = 0.0;
	double resist_timer = 0.0;
	double stuck_time = 0.0;
	double car_spin = 0.0;
	double last_car_rotation = 0.0;
	double last_car_touch = -INFINITY;
	Vector2 lock_pos;
	Vector2 lock_dir = Vector2(1, 0);
	int my_mode = MOVE;

	AnimatedSprite2D *sprite = nullptr;
	ObjectID car_id; // the car of this tick (beginTick)

	static Rect2 physics_view;

	bool lethal_here(const Vector2 &p_pos);

protected:
	static void _bind_methods();

public:
	static constexpr int WATER_TICKS = 4;               // the water check runs every this many ticks, staggered
	static constexpr double WALK_CYCLE_PER_R = 3.4;     // ground covered by one 8-frame walk cycle, in body radii
	static constexpr double TOUCH_REACH = 110.0;        // the bumper counts as a touch this far past the body

	GoonBody();

	static void init_names();
	static void free_names();

	// fields
	void set_speed(double p_value) { speed = p_value; }
	double get_speed() const { return speed; }
	void set_turn_rate(double p_value) { turn_rate = p_value; }
	double get_turn_rate() const { return turn_rate; }
	void set_body_radius(double p_value) { body_radius = p_value; }
	double get_body_radius() const { return body_radius; }
	void set_buff_scale(double p_value) { buff_scale = p_value; }
	double get_buff_scale() const { return buff_scale; }
	void set_buff_until(double p_value) { buff_until = p_value; }
	double get_buff_until() const { return buff_until; }
	void set_state_name(const StringName &p_value) { state = p_value; }
	StringName get_state_name() const { return state; }
	void set_state_time(double p_value) { state_time = p_value; }
	double get_state_time() const { return state_time; }
	void set_cooldown(double p_value) { cooldown = p_value; }
	double get_cooldown() const { return cooldown; }
	void set_resist_timer(double p_value) { resist_timer = p_value; }
	double get_resist_timer() const { return resist_timer; }
	void set_stuck_time(double p_value) { stuck_time = p_value; }
	double get_stuck_time() const { return stuck_time; }
	void set_car_spin(double p_value) { car_spin = p_value; }
	double get_car_spin() const { return car_spin; }
	void set_last_car_rotation(double p_value) { last_car_rotation = p_value; }
	double get_last_car_rotation() const { return last_car_rotation; }
	void set_last_car_touch(double p_value) { last_car_touch = p_value; }
	double get_last_car_touch() const { return last_car_touch; }
	void set_lock_pos(const Vector2 &p_value) { lock_pos = p_value; }
	Vector2 get_lock_pos() const { return lock_pos; }
	void set_lock_dir(const Vector2 &p_value) { lock_dir = p_value; }
	Vector2 get_lock_dir() const { return lock_dir; }
	void set_my_mode(int p_value) { my_mode = p_value; }
	int get_my_mode() const { return my_mode; }

	// the tick
	void bind_sprite(AnimatedSprite2D *p_sprite);
	bool begin_tick(double p_delta, Node2D *p_car);
	void tick_timers(double p_delta, Node2D *p_car);
	bool over_deep_water(Node2D *p_car);
	void touched_by_car();

	// helpers the verbs use
	double speed_now() const;
	bool is_buffed() const;
	double dist_to(Node2D *p_car) const;
	void set_state(const StringName &p_state);
	void play(const StringName &p_anim, double p_duration);
	void walk_anim(double p_move_speed);
	void face_to(double p_angle, double p_delta, double p_rate);
	void chase(const Vector2 &p_target, double p_move_speed, double p_delta, double p_rate);
	void advance(const Vector2 &p_velocity, double p_delta);
	Vector2 predict(Node2D *p_car, double p_lead) const;
	void lock_on(Node2D *p_car, double p_lead);

	// SpawnManager's off-screen LOD view (SpawnManager.physicsView); no area means full physics everywhere
	static void set_physics_view(const Rect2 &p_view);
	static Rect2 get_physics_view();
	static bool needs_full_physics(const Vector2 &p_point);
};

} // namespace godot
