module libconfig;

import deimos.libconfig;
import std.variant;
import std.file;
import std.conv;
import std.string;
import std.exception;

class Config
{
	enum Format {
		Default,
		Hex
	}

	enum Type {
		None,
		Group,
		Int,
		Long,
		Float,
		String,
		Bool,
		Array,
		List
	}

	alias Algebraic!(Type, int, long, double, string, bool) Value;

	Type to(T : Type) (Value value)
	{
		if (value.type == typeid(int)) {
			return Type.Int;
		}
		else if (value.type == typeid(long)) {
			return Type.Long;
		}
		else if (value.type == typeid(double)) {
			return Type.Float;
		}
		else if (value.type == typeid(string)) {
			return Type.String;
		}
		else if (value.type == typeid(bool)) {
			return Type.Bool;
		}
		else {
			return value.get!Type;
		}
	}

	static class Setting
	{
		struct Source {
			string file;
			ushort line;
		}

		this (config_setting_t* value)
		{
			_internal = value;
		}

		override bool opEquals (Object other)
		{
			if (other is this) {
				return true;
			}

			if (auto setting = cast (Setting) other) {
				return native == setting.native;
			}

			return false;
		}

		Setting opIndex (string path)
		{
			enforce(isGroup, "the Setting has to be a Group");

			if (auto setting = config_setting_get_member(native, path.toStringz())) {
				return new Setting(setting);
			}

			if (auto setting = config_lookup_from(native, path.toStringz())) {
				return new Setting(setting);
			}

			return null;
		}

		Setting opIndex (uint index)
		{
			enforce(isList || isArray, "the Setting has to be either an Array or List");
			enforceEx!RangeError(index < length);

			return new Setting(config_setting_get_elem(native, index));
		}

		void opIndexAssign (Value value, string name)
		{
			enforce(isGroup, "the Setting has to be a Group");

			auto setting       = new Setting(config_setting_add(native, name.toStringz(), value.to!Type));
			     setting.value = value;
		}

		void opIndexAssign (Value[] values, string name)
		{
			enforce(isGroup, "the Setting has to be a Group");

			auto setting = new Setting(config_setting_add(native, name.toStringz(), Type.List));
		}

		void opIndexAssign (Value[string] values, string name)
		{
			enforce(isGroup, "the Setting has to be a Group");

			auto setting = new Setting(config_setting_add(native, name.toStringz(), Type.Group));
		}

		void opIndexAssign (Value value, uint index)
		{
			enforce(isList || isArray, "the Setting has to be either an Array or List");
			enforceEx!RangeError(index < length);
		}

		void opIndexAssign (Value[] value, uint index)
		{
			enforce(isList || isArray, "the Setting has to be either an Array or List");
			enforceEx!RangeError(index < length);
		}

		void opIndexAssign (Value[string] value, uint index)
		{
			enforce(isList || isArray, "the Setting has to be either an Array or List");
			enforceEx!RangeError(index < length);
		}

		void pushBack (Value value)
		{
			enforce(isList || isArray, "the Setting has to be either an Array or List");

			auto setting       = new Setting(config_setting_add(native, null, value.to!Type));
			     setting.value = value;
		}

		void pushBack (Value[] values)
		{
			enforce(isList || isArray, "the Setting has to be either an Array or List");

			auto setting = new Setting(config_setting_add(native, name.toStringz(), Type.List));
		}

		void pushBack (Value[string] values)
		{
			enforce(isList || isArray, "the Setting has to be either an Array or List");

			auto setting = new Setting(config_setting_add(native, name.toStringz(), Type.Group));
		}

		int indexOf (Setting setting)
		{
			enforce(this == setting.parent);

			return config_setting_index(setting.native);
		}

		bool remove (string name)
		{
			enforce(isGroup, "the Setting has to be a Group");

			return config_setting_remove(native, name.toStringz());
		}

		bool remove (uint index)
		{
			enforce(isList || isArray, "the Setting has to be either an Array or List");

			return config_setting_remove_elem(native, index);
		}

		@property type ()
		{
			return cast (Type) config_setting_type(native);
		}

		@property value (Value value)
		{

		}

		@property Value value ()
		{
			final switch (type) {
				case Type.None:
				case Type.Group:
				case Type.Array:
				case Type.List:
					return type;

				case Type.Int:
					return config_setting_get_int(native);

				case Type.Long:
					return config_setting_get_int64(native);

				case Type.Float:
					return config_setting_get_float(native);

				case Type.Bool:
					return config_setting_get_bool(native);

				case Type.String:
					return config_setting_get_string(native).to!string;
			}
		}

		@property length ()
		{
			return config_setting_length(native);
		}

		@property empty ()
		{
			return length == 0;
		}

		@property isGroup ()
		{
			return config_setting_is_group(native);
		}

		@property isArray ()
		{
			return config_setting_is_array(native);
		}

		@property isList ()
		{
			return config_setting_is_list(native);
		}

		@property isAggregate ()
		{
			return config_setting_is_aggregate(native);
		}

		@property isNumber ()
		{
			return config_setting_is_number(native);
		}

		@property isScalar ()
		{
			return config_setting_is_scalar(native);
		}

		@property name ()
		{
			return config_setting_name(native).to!string;
		}

		@property parent ()
		{
			if (auto setting = config_setting_parent(native)) {
				return new Setting(setting);
			}

			return null;
		}

		@property isRoot ()
		{
			return config_setting_is_root(native);
		}

		@property format ()
		{
			return cast (Format) config_setting_get_format(native);
		}
		
		@property format (Format value)
		{
			config_setting_set_format(native, cast (short) value);
		}

		@property source ()
		{
			return Source(config_setting_source_file(native).to!string, config_setting_source_line(native));
		}

		@property native ()
		{
			return _internal;
		}

	private:
		config_setting_t* _internal;
	}

	this (FILE* input)
	{
		config_init(native);
		config_read(native, input);
	}

	this (string input)
	{
		config_init(native);

		if (exists(input)) {
			config_read_file(native, input.toStringz());
		}
		else {
			config_read_string(native, input.toStringz());
		}
	}

	~this ()
	{
		config_destroy(native);
	}

	void save (FILE* output)
	{
		config_write(native, output);
	}

	void save (string path)
	{
		config_write_file(native, path.toStringz());
	}

	Setting opIndex (string path)
	{
		if (auto setting = config_lookup(native, path.toStringz())) {
			return new Setting(setting);
		}

		return null;
	}

	@property root ()
	{
		return new Setting(config_root_setting(native));
	}

	@property autoConvert ()
	{
		return config_get_auto_convert(native);
	}

	@property autoConvert (bool value)
	{
		config_set_auto_convert(native, value);
	}

	@property includeDir ()
	{
		return config_get_include_dir(native);
	}

	@property includeDir (string path)
	{
		config_set_include_dir(native, path.toStringz());
	}

	@property defaultFormat ()
	{
		return cast (Format) config_get_default_format(native);
	}

	@property defaultFormat (Format format)
	{
		config_set_default_format(native, cast (short) format);
	}

	@property tabWidth ()
	{
		return config_get_tab_width(native);
	}

	@property tabWidth (ushort width)
	{
		config_set_tab_width(native, width);
	}

	@property native ()
	{
		return &_config;
	}

private:
	config_t _config;
}
