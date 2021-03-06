module libconfig;

import deimos.libconfig;
import std.variant;
import std.file;
import std.conv;
import std.string;
import std.exception;
import std.array;

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

	alias Variant Value;

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

		bool opIn_r (string path)
		{
			return this[path] !is null;
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

		void opIndexAssign (Value value, string name)
		{
			enforce(isGroup, "the Setting has to be a Group");

			auto setting       = name in this ? this[name] : new Setting(config_setting_add(native, name.toStringz(), value.toType), _config);
			     setting.value = value;
		}

		void opIndexAssign (Value value, uint index)
		{
			enforce(isAggregate, "the Setting has to be an Aggregate");
			enforce(index < length, new RangeError);

			auto setting       = this[index];
			     setting.value = value;
		}

		Range opSlice ()
		{
			return Range(this);
		}

		int opApply (int delegate (string, Setting) block)
		{
			enforce(isGroup, "you can only foreach over a Group");

			int result = 0;

			foreach (setting; this[]) {
				result = block(setting.name, setting);

				if (result) {
					break;
				}
			}

			return result;
		}

		int opApplyReverse (int delegate (string, Setting) block)
		{
			enforce(isGroup, "you can only foreach_reverse over a Group");

			int result = 0;

			foreach_reverse (setting; this[]) {
				result = block(setting.name, setting);

				if (result) {
					break;
				}
			}

			return result;
		}

		@property front ()
		{
			return this[0];
		}

		@property back ()
		{
			return this[this.length - 1];
		}

		void popBack ()
		{
			assert(!empty, "Attempting to pop back of an empty Setting");

			remove(length - 1);
		}

		void popFront ()
		{
			assert(!empty, "Attempting to pop front of an empty Setting");

			remove(0);
		}

		void pushBack (Value value)
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

		void clear ()
		{
			while (!empty) {
				popBack();
			}
		}

		@property type ()
		{
			return cast (Type) config_setting_type(native);
		}

		@property value (Value value)
		{
			enforce(value.toType != Type.None, "value unsupported");

			if (isAggregate) {
				clear();
			}

			native.type = cast (short) value.toType;

			final switch (value.toType) {
				case Type.None:
					assert(0);

				case Type.Group:
					foreach (name, val; value.get!(Value[string])) {
						this[name] = val;
					}

					break;

				case Type.Array:
				case Type.List:
					foreach (val; value.get!(Value[])) {
						pushBack(val);
					}

					break;

				case Type.Int:
					config_setting_set_int(native, value.get!int);
					break;

				case Type.Long:
					config_setting_set_int64(native, value.get!long);
					break;

				case Type.Float:
					config_setting_set_float(native, value.get!double);
					break;

				case Type.Bool:
					config_setting_set_bool(native, value.get!bool);
					break;

				case Type.String:
					config_setting_set_string(native, value.get!(string).toStringz());
					break;
			}
		}

		@property value (int val)
		{
			value = Value(val);
		}

		@property value (long val)
		{
			value = Value(val);
		}

		@property value (double val)
		{
			value = Value(val);
		}

		@property value (bool val)
		{
			value = Value(val);
		}

		@property value ()
		{
			final switch (type) {
				case Type.None:
					return Value(null);

				case Type.Group:
					Value[string] result;

					foreach (name, setting; this) {
						result[name] = setting.value;
					}

					return Value(result);

				case Type.Array:
				case Type.List:
					Value[] result;

					foreach (setting; this[]) {
						result ~= setting.value;
					}

					return Value(result);

				case Type.Int:
					return Value(config_setting_get_int(native));

				case Type.Long:
					return Value(config_setting_get_int64(native));

				case Type.Float:
					return Value(config_setting_get_float(native));

				case Type.Bool:
					return Value(config_setting_get_bool(native));

				case Type.String:
					return Value(config_setting_get_string(native).to!string);
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

		override string toString ()
		{
			return value.toString();
		}

	private:
		config_setting_t* _internal;
		Config            _config;
	}

	this (FILE* input)
	{
		_internal = new config_t;

		config_init(native);
		config_read(native, input);
	}

	this (string input)
	{
		_internal = new config_t;

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
		_internal = config;
		_wrapper  = true;
	}

	~this ()
	{
		if (!isWrapper) {
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
		return _internal;
	}

	@property isWrapper ()
	{
		return _wrapper;
	}

private:
	config_t* _internal;
	bool      _wrapper;
}

private:
	Config.Type toType (Config.Value value)
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
		else if (value.type == typeid(Config.Value[])) {
			auto list = value.get!(Config.Value[]);

			if (list.empty) {
				return Config.Type.List;
			}

			auto first = list[0].type;

			foreach (piece; list) {
				if (piece.type != first) {
					return Config.Type.List;
				}
			}

			return Config.Type.Array;
		}
		else if (value.type == typeid(Config.Value[string])) {
			return Config.Type.Group;
		}
		else {
			return Config.Type.None;
		}
	}
