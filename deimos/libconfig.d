/* ----------------------------------------------------------------------------
   libconfig - A library for processing structured configuration files
   Copyright (C) 2005-2010  Mark A Lindner

   This file is part of libconfig.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public License
   as published by the Free Software Foundation; either version 2.1 of
   the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; if not, see
   <http://www.gnu.org/licenses/>.
   ----------------------------------------------------------------------------
*/

module deimos.libconfig;

public import std.c.stdio;

nothrow extern (C):

const LIBCONFIG_VER_MAJOR    = 1;
const LIBCONFIG_VER_MINOR    = 4;
const LIBCONFIG_VER_REVISION = 8;

enum {
	CONFIG_TYPE_NONE,
	CONFIG_TYPE_GROUP,
	CONFIG_TYPE_INT,
	CONFIG_TYPE_INT64,
	CONFIG_TYPE_FLOAT,
	CONFIG_TYPE_STRING,
	CONFIG_TYPE_BOOL,
	CONFIG_TYPE_ARRAY,
	CONFIG_TYPE_LIST
}

enum {
	CONFIG_FORMAT_DEFAULT,
	CONFIG_FORMAT_HEX
}

enum {
	CONFIG_OPTION_AUTOCONVERT
}

enum {
	CONFIG_FALSE,
	CONFIG_TRUE
}

union config_value_t {
	int            ival;
	long           llval;
	double         fval;
	char*          sval;
	config_list_t* list;
}

struct config_setting_t {
	char* name;
	short type;
	short format;

	config_value_t    value;
	config_setting_t* parent;
	config_t*         config;

	void* hook;

	uint        line;
	const char* file;
}

enum config_error_t {
	CONFIG_ERR_NONE,
	CONFIG_ERR_FILE_IO,
	CONFIG_ERR_PARSE
}

struct config_list_t {
	uint               length;
	config_setting_t** elements;
}

struct config_t {
	config_setting_t* root;

	void function (void*) destructor;

	ushort flags;
	ushort tab_width;

	short default_format;

	const char* include_dir;

	const char*    error_text;
	const char*    error_file;
	int            error_line;
	config_error_t error_type;

	const char** filenames;
	uint         num_filenames;
}

int config_read (config_t* config, FILE* stream);
void config_write (const config_t* config, FILE* stream);

void config_set_auto_convert (config_t* config, bool flag);
bool config_get_auto_convert (const config_t* config);

int config_read_string (config_t* config, const char* str);

int config_read_file (config_t* config, const char* filename);
int config_write_file (config_t* config, const char* filename);

void config_set_destructor (config_t* config, void function (void*) destructor);
void config_set_include_dir (config_t* config, const char* include_dir);

void config_init (config_t* config);
void config_destroy (config_t* config);

int config_setting_get_int (const config_setting_t* setting);
long config_setting_get_int64 (const config_setting_t* setting);
double config_setting_get_float (const config_setting_t* setting);
bool config_setting_get_bool (const config_setting_t* setting);
const(char*) config_setting_get_string (const config_setting_t* setting);

bool config_setting_lookup_int (const config_setting_t* setting, const char* name, int* value);
bool config_setting_lookup_int64 (const config_setting_t* setting, const char* name, long* value);
bool config_setting_lookup_float (const config_setting_t* setting, const char* name, double* value);
bool config_setting_lookup_bool (const config_setting_t* setting, const char* name, bool* value);
bool config_setting_lookup_string (const config_setting_t* setting, const char* name, const char** value);

bool config_setting_set_int (config_setting_t* setting, int value);
bool config_setting_set_int64 (config_setting_t* setting, long value);
bool config_setting_set_float (config_setting_t* setting, double value);
bool config_setting_set_bool (config_setting_t* setting, bool value);
bool config_setting_set_string (config_setting_t* setting, const char* value);

bool config_setting_set_format (config_setting_t* setting, short format);
short config_setting_get_format (const config_setting_t* setting);

int config_setting_get_int_elem (const config_setting_t* setting, int idx);
long config_setting_get_int64_elem (const config_setting_t* setting, int idx);
double config_setting_get_float_elem (const config_setting_t* setting, int idx);
bool config_setting_get_bool_elem (const config_setting_t* setting, int idx);
const (char*) config_setting_get_string_elem (const config_setting_t* setting, int idx);

config_setting_t* config_setting_set_int_elem (config_setting_t* setting, int idx, int value);
config_setting_t* config_setting_set_int64_elem (config_setting_t* setting, int idx, long value);
config_setting_t* config_setting_set_float_elem (config_setting_t* setting, int idx, double value);
config_setting_t* config_setting_set_bool_elem (config_setting_t* setting, int idx, bool value);
config_setting_t* config_setting_set_string_elem (config_setting_t* setting, int idx, const char* value);

const (char*) config_get_include_dir (const config_t* config)
{
	return config.include_dir;
}

int config_setting_type (const config_setting_t* setting)
{
	return setting.type;
}

bool config_setting_is_group (const config_setting_t* setting)
{
	return setting.type == CONFIG_TYPE_GROUP;
}

bool config_setting_is_array (const config_setting_t* setting)
{
	return setting.type == CONFIG_TYPE_ARRAY;
}

bool config_setting_is_list (const config_setting_t* setting)
{
	return setting.type == CONFIG_TYPE_LIST;
}

bool config_setting_is_aggregate (const config_setting_t* setting)
{
	return setting.type == CONFIG_TYPE_GROUP || setting.type == CONFIG_TYPE_LIST || setting.type == CONFIG_TYPE_ARRAY;
}

bool config_setting_is_number (const config_setting_t* setting)
{
	return setting.type == CONFIG_TYPE_INT || setting.type == CONFIG_TYPE_INT64 || setting.type == CONFIG_TYPE_FLOAT;
}

bool config_setting_is_scalar (const config_setting_t* setting)
{
	return setting.type == CONFIG_TYPE_BOOL || setting.type == CONFIG_TYPE_STRING || config_setting_is_scalar(setting);
}

const (char*) config_setting_name (const config_setting_t* setting)
{
	return setting.name;
}

config_setting_t* config_setting_parent (const config_setting_t* setting)
{
	return cast (config_setting_t*) setting.parent;
}

bool config_setting_is_root (const config_setting_t* setting)
{
	return setting.parent is null;
}

int config_setting_index (const config_setting_t* setting);

int config_setting_length (const config_setting_t* setting);

config_setting_t* config_setting_get_elem (const config_setting_t* setting, uint idx);

config_setting_t* config_setting_get_member (const config_setting_t* setting, const char* name);

config_setting_t* config_setting_add (config_setting_t* parent, const char* name, int type);

bool config_setting_remove (config_setting_t* parent, const char* name);

bool config_setting_remove_elem (config_setting_t* parent, uint idx);

void config_setting_set_hook (config_setting_t* setting, void* hook);

void* config_setting_get_hook (config_setting_t* setting)
{
	return setting.hook;
}

config_setting_t* config_lookup (const config_t* config, const char* path);
config_setting_t* config_lookup_from (config_setting_t* setting, const char* path);

bool config_lookup_int (const config_t* config, const char* path, int* value);
bool config_lookup_int64 (const config_t* config, const char* path, long* value);
bool config_lookup_float (const config_t* config, const char* path, double* value);
bool config_lookup_bool (const config_t* config, const char* path, bool* value);
bool config_lookup_string (const config_t* config, const char* path, const char** value);

config_setting_t* config_root_setting (const config_t* config)
{
	return cast (config_setting_t*) config.root;
}

void config_set_default_format (config_t* config, short format)
{
	config.default_format = format;
}

short config_get_default_format (config_t* config)
{
	return config.default_format;
}

void config_set_tab_width (config_t* config, ushort width)
{
	config.tab_width = width & 0x0F;
}

ushort config_get_tab_width (const config_t* config)
{
	return config.tab_width;
}

uint config_setting_source_line (const config_setting_t* setting)
{
	return setting.line;
}

const (char*) config_setting_source_file (const config_setting_t* setting)
{
	return setting.file;
}

const (char*) config_error_text (const config_t* config)
{
	return config.error_text;
}

const (char*) config_error_file (const config_t* config)
{
	return config.error_file;
}

int config_error_line (const config_t* config)
{
	return config.error_line;
}

config_error_t config_error_type (const config_t* config)
{
	return config.error_type;
}
