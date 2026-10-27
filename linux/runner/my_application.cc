#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

static const char kWindowChannel[] = "dev.elias.sepia_reader/window";

// The header bar is drawn by GTK, not Flutter, so the app sends its colours
// over this channel. Only the header bar is styled; the rest of the window
// keeps the GTK theme.
static const char kHeaderBarCss[] =
    "@define-color sepia_header_background %s;\n"
    "@define-color sepia_header_foreground %s;\n"
    "@define-color sepia_header_hover %s;\n"
    "headerbar,\n"
    "headerbar:backdrop {\n"
    "  background: @sepia_header_background;\n"
    "  background-image: none;\n"
    "  border: none;\n"
    "  box-shadow: none;\n"
    "  color: @sepia_header_foreground;\n"
    "}\n"
    "headerbar label,\n"
    "headerbar button,\n"
    "headerbar button:backdrop {\n"
    "  color: @sepia_header_foreground;\n"
    "  text-shadow: none;\n"
    "}\n"
    "headerbar button,\n"
    "headerbar button:backdrop {\n"
    "  background: none;\n"
    "  background-image: none;\n"
    "  border-color: transparent;\n"
    "  box-shadow: none;\n"
    "}\n"
    "headerbar button:hover,\n"
    "headerbar button:active {\n"
    "  background: @sepia_header_hover;\n"
    "  background-image: none;\n"
    "  border-color: transparent;\n"
    "}\n";

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  FlMethodChannel* window_channel;
  GtkCssProvider* header_css;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Dart colours are ARGB; GTK CSS takes RGB.
static void split_argb(gint64 argb, guint* red, guint* green, guint* blue) {
  *red = (argb >> 16) & 0xff;
  *green = (argb >> 8) & 0xff;
  *blue = argb & 0xff;
}

static void apply_header_colors(MyApplication* self, gint64 background,
                                gint64 foreground) {
  if (self->header_css == nullptr) {
    return;
  }
  guint red, green, blue;
  split_argb(background, &red, &green, &blue);
  g_autofree gchar* background_css =
      g_strdup_printf("#%02x%02x%02x", red, green, blue);
  split_argb(foreground, &red, &green, &blue);
  g_autofree gchar* foreground_css =
      g_strdup_printf("#%02x%02x%02x", red, green, blue);
  // A faint wash of the foreground colour marks the hovered header button.
  g_autofree gchar* hover_css =
      g_strdup_printf("rgba(%u, %u, %u, 0.12)", red, green, blue);
  g_autofree gchar* css = g_strdup_printf(kHeaderBarCss, background_css,
                                          foreground_css, hover_css);

  g_autoptr(GError) error = nullptr;
  gtk_css_provider_load_from_data(self->header_css, css, -1, &error);
  if (error != nullptr) {
    g_warning("Failed to style the header bar: %s", error->message);
  }
}

static void window_method_call_cb(FlMethodChannel* channel,
                                  FlMethodCall* method_call,
                                  gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  g_autoptr(GError) error = nullptr;

  if (g_strcmp0(fl_method_call_get_name(method_call), "setHeaderColors") !=
      0) {
    fl_method_call_respond_not_implemented(method_call, &error);
  } else {
    FlValue* args = fl_method_call_get_args(method_call);
    FlValue* background =
        args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP
            ? fl_value_lookup_string(args, "background")
            : nullptr;
    FlValue* foreground =
        args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP
            ? fl_value_lookup_string(args, "foreground")
            : nullptr;
    if (background == nullptr || foreground == nullptr ||
        fl_value_get_type(background) != FL_VALUE_TYPE_INT ||
        fl_value_get_type(foreground) != FL_VALUE_TYPE_INT) {
      fl_method_call_respond_error(
          method_call, "bad-arguments",
          "setHeaderColors needs ARGB background and foreground integers.",
          nullptr, &error);
    } else {
      apply_header_colors(self, fl_value_get_int(background),
                          fl_value_get_int(foreground));
      fl_method_call_respond_success(method_call, nullptr, &error);
    }
  }

  if (error != nullptr) {
    g_warning("Failed to answer the window channel: %s", error->message);
  }
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "Sépia");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));

    self->header_css = gtk_css_provider_new();
    gtk_style_context_add_provider_for_screen(
        gtk_widget_get_screen(GTK_WIDGET(window)),
        GTK_STYLE_PROVIDER(self->header_css),
        GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
  } else {
    gtk_window_set_title(window, "Sépia");
  }

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Created with the view so the Dart side can send its colours before the
  // first frame.
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->window_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)), kWindowChannel,
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(self->window_channel,
                                            window_method_call_cb, self,
                                            nullptr);

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  g_clear_object(&self->window_channel);
  g_clear_object(&self->header_css);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
