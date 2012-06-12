module libconfig;

import deimos.libconfig;
import std.variant;
import std.file;
import std.conv;
import std.string;
import std.exception;

class Config
{
	enum Format
	{
		Default,
		Hex
	}

	enum Type
	{
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

	static class Setting
	{
		struct Source
		{
			string file;
			uint   line;
		}

		struct Range
		{
			private Setting _setting;
			private uint    _current;
			private uint    _length;

			this (Setting setting)
			{
				assert(setting.isAggregate);

				_setting = setting;
				_length  = setting.length;
				_current = 0;
			}

			@property bool empty ()
			{
				return _current == _length;
			}

			@property uint length ()
			{
				return _length - _current;
			}

			@property front ()
			{
				return _setting[_current];
			}

			@property back ()
			{
				return _setting[_length - 1];
			}

			void popFront ()
			{
				enforce(!empty);

				_current++;
			}

			void popBack ()
			{
				enforce(!empty);

				_length--;
			}
		}

		this (config_setting_t* value)
		{
			_internal = value;
		}

		this (config_setting_t* value, Config config)
		{
			this(value);

			_config = config;
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
				return new Setting(setting, _config);
			}

			if (auto setting = config_lookup_from(native, path.toStringz())) {
				return new Setting(setting, _config);
			}

			return null;
		}

		Setting opIndex (uint index)
		{
			enforce(isAggregate, "the Setting has to be either an Array or List");
			enforce(index < length, new RangeError);

			return new Setting(config_setting_get_elem(native, index), _config);
		}

		void opIndexAssign (Variant value, string name)
		{
			enforce(isGroup, "the Setting has to be a Group");
			enforce(value.toType != Type.None);

			auto setting       = new Setting(config_setting_add(native, name.toStringz(), value.toType), _config);
			     setting.value = value;
		}

		void opIndexAssign (Variant value, uint index)
		{
			enforce(isAggregate, "the Setting has to be an Aggregate");
			enforce(index < length, new RangeError);
			enforce(value.toType != Type.None);
		}

		Range opSlice ()
		{
			return Range(this);
		}

		int opApply (int delegate (string, Setting) block)
		{
			int result = 0;

			foreach (setting; opSlice()) {
				result = block(setting.name, setting);

				if (result) {
					break;
				}
			}

			return result;
		}

		int opApplyReverse (int delegate (string, Setting) block)
		{
			int result = 0;

			foreach_reverse (setting; opSlice()) {
				result = block(setting.name, setting);

				if (result) {
					break;
				}
			}

			return result;
		}

		void pushBack (Variant value)
		{
			enforce(isList || isArray, "the Setting has to be either an Array or List");

			auto setting       = new Setting(config_setting_add(native, null, value.toType), _config);
			     setting.value = value;
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
			enforce(isAggregate, "the Setting has to be either an Array or List");

			return config_setting_remove_elem(native, index);
		}

		@property type ()
		{
			return cast (Type) config_setting_type(native);
		}

		@property value (Variant value)
		{

		}

		@property Variant value ()
		{
			final switch (type) {
				case Type.None:
					return Variant(null);

				case Type.Group:
					Variant[string] result;

					foreach (name, setting; this) {
						result[name] = setting.value;
					}

					return Variant(result);

				case Type.Array:
				case Type.List:
					Variant[] result;

					foreach (setting; this[]) {
						result ~= setting.value;
					}

					return Variant(result);

				case Type.Int:
					return Variant(config_setting_get_int(native));

				case Type.Long:
					return Variant(config_setting_get_int64(native));

				case Type.Float:
					return Variant(config_setting_get_float(native));

				case Type.Bool:
					return Variant(config_setting_get_bool(native));

				case Type.String:
					return Variant(config_setting_get_string(native).to!string);
			}
		}

		@property length ()
		{
			return config_setting_length(native);
		}

		@property empty ()
		{
			return type == Type.None || length == 0;
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
				return new Setting(setting, _config);
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

		@property config ()
		{
			return _config ? _config : new Config(config_setting_config(native));
		}

		@property native ()
		{
			return _internal;
		}

	private:
		config_setting_t* _internal;
		Config            _config;
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

	this (config_t* config)
	{
		_wrapped = config;
	}

	~this ()
	{
		if (!_wrapped) {
			config_destroy(native);
		}
	}

	void save (FILE* output)
	{
		config_write(native, output);
	}

	void save (string path)
	{
		config_write_file(native, path.toStringz());
	}

	auto opIndex (string path)
	{
		return root[path];
	}

	auto opSlice ()
	{
		return root.opSlice();
	}

	int opApply (int delegate (string, Setting) block)
	{
		return root.opApply(block);
	}

	int opApplyReverse (int delegate (string, Setting) block)
	{
		return root.opApplyReverse(block);
	}

	@property root ()
	{
		return new Setting(config_root_setting(native), this);
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
		return _wrapped ? _wrapped : &_config;
	}

private:
	config_t  _config;
	config_t* _wrapped;
}

private:
	Config.Type toType (Variant value)
	{
		if (value.type == typeid(int)) {
			return Config.Type.Int;
		}
		else if (value.type == typeid(long)) {
			return Config.Type.Long;
		}
		else if (value.type == typeid(double)) {
			return Config.Type.Float;
		}
		else if (value.type == typeid(string)) {
			return Config.Type.String;
		}
		else if (value.type == typeid(bool)) {
			return Config.Type.Bool;
		}
		else if (value.type == typeid(Variant[])) {
			return Config.Type.List;
		}
		else if (value.type == typeid(Variant[string])) {
			return Config.Type.Group;
		}
		else {
			return Config.Type.None;
		}
	}
