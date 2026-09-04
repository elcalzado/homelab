{ lib, ... }:
{
  services.klipper.settings = {
    mcu = {
      serial = "/dev/serial/by-id/usb-1a86_USB_Serial-if00-port0";
      restart_method = "command";
    };

    "temperature_sensor mcu_temp" = {
      sensor_type = "temperature_mcu";
      min_temp = 0;
      max_temp = 100;
    };

    "temperature_sensor raspberry_pi" = {
      sensor_type = "temperature_host";
      min_temp = 10;
      max_temp = 100;
    };

    printer = {
      kinematics = "cartesian";
      max_velocity = 250;
      max_accel = 2500;
      minimum_cruise_ratio = 0.5;
      square_corner_velocity = 5.0;
      max_z_velocity = 100;
      max_z_accel = 500;
    };

    stepper_x = {
      step_pin = "PC2";
      dir_pin = "!PB9";
      enable_pin = "!PC3";
      microsteps = 16;
      rotation_distance = 40;
      endstop_pin = "!PA5";
      position_endstop = -6;
      position_min = -6;
      position_max = 230;
      homing_speed = 60;
    };

    "tmc2209 stepper_x" = {
      uart_pin = "PB12";
      run_current = 0.6;
      sense_resistor = 0.150;
      stealthchop_threshold = 0;
      interpolate = true;
    };

    stepper_y = {
      step_pin = "PB8";
      dir_pin = "PB7";
      enable_pin = "!PC3";
      microsteps = 16;
      rotation_distance = 40;
      endstop_pin = "!PA6";
      position_endstop = -14;
      position_min = -14;
      position_max = 225;
      homing_speed = 60;
    };

    "tmc2209 stepper_y" = {
      uart_pin = "PB13";
      run_current = 0.6;
      sense_resistor = 0.150;
      stealthchop_threshold = 0;
      interpolate = true;
    };

    stepper_z = {
      step_pin = "PB6";
      dir_pin = "!PB5";
      enable_pin = "!PC3";
      microsteps = 16;
      rotation_distance = 8;
      endstop_pin = "probe:z_virtual_endstop";
      position_min = -3;
      position_max = 250;
      homing_speed = 5;
      second_homing_speed = 1;
      homing_retract_dist = 2.5;
    };

    "tmc2209 stepper_z" = {
      uart_pin = "PB14";
      run_current = 0.8;
      sense_resistor = 0.150;
      stealthchop_threshold = 0;
      interpolate = true;
    };

    extruder = {
      step_pin = "PB4";
      dir_pin = "PB3";
      enable_pin = "!PC3";
      microsteps = 16;
      rotation_distance = 7.663;
      nozzle_diameter = 0.400;
      filament_diameter = 1.750;
      max_extrude_cross_section = 5;
      max_extrude_only_distance = 500;
      pressure_advance = 0.04;
      heater_pin = "PA1";
      sensor_type = "EPCOS 100K B57560G104F";
      sensor_pin = "PC5";
      control = "pid";
      pid_Kp = 28.168;
      pid_Ki = 1.456;
      pid_Kd = 136.265;
      min_temp = 0;
      max_temp = 260;
    };

    heater_bed = {
      heater_pin = "PB2";
      sensor_type = "EPCOS 100K B57560G104F";
      sensor_pin = "PC4";
      control = "pid";
      pid_Kp = 63.283;
      pid_Ki = 0.618;
      pid_Kd = 1620.843;
      min_temp = 0;
      max_temp = 100;
    };

    bed_mesh = {
      speed = 150;
      mesh_min = "10,10";
      mesh_max = "206,210.5";
      probe_count = "5,5";
      algorithm = "bicubic";
    };

    bltouch = {
      sensor_pin = "^PC14";
      control_pin = "PC13";
      stow_on_each_sample = false;
      probe_with_touch_mode = true;
      x_offset = -24.0;
      y_offset = -14.5;
      z_offset = 1.772;
      speed = 5;
      samples = 3;
      lift_speed = 10;
    };

    "heater_fan hotend_fan".pin = "PC1";
    fan.pin = "PA0";

    idle_timeout = {
      gcode = "OFF";
      timeout = 600;
    };

    safe_z_home = {
      home_xy_position = "139,127";
      speed = 60;
      z_hop = 10;
      z_hop_speed = 5;
    };

    "bed_mesh default" = {
      version = 1;
      points = ''
        0.632500, 0.480000, 0.207500, -0.041667, -0.336667
        0.628333, 0.429167, 0.165833, -0.055833, -0.364167
        0.481667, 0.320833, 0.083333, -0.155833, -0.441667
        0.365000, 0.195000, -0.011667, -0.223333, -0.483333
        0.235833, 0.115000, -0.101667, -0.295000, -0.522500
      '';
      x_count = 5;
      y_count = 5;
      mesh_x_pps = 2;
      mesh_y_pps = 2;
      algo = "lagrange";
      tension = 0.2;
      min_x = 10.0;
      max_x = 206.0;
      min_y = 10.0;
      max_y = 210.48;
    };

    "output_pin beeper".pin = "PB0";
    gcode_arcs = { };
    exclude_object = { };
  };

  services.klipper.extraSettings = lib.concatStringsSep "\n" [
    (builtins.readFile ./mainsail.cfg)
    (builtins.readFile ./macros.cfg)
    (lib.replaceStrings [
      "[include ./KAMP/Adaptive_Meshing.cfg]       # Include to enable adaptive meshing configuration.\n"
      "[include ./KAMP/Line_Purge.cfg]             # Include to enable adaptive line purging configuration.\n"
      "#[include ./KAMP/Voron_Purge.cfg]            # Include to enable adaptive Voron logo purging configuration.\n"
      "[include ./KAMP/Smart_Park.cfg]             # Include to enable the Smart Park function, which parks the printhead near the print area for final heating.\n"
    ] [ "" "" "" "" ] (builtins.readFile ./KAMP_Settings.cfg))
    (builtins.readFile ./KAMP/Adaptive_Meshing.cfg)
    (builtins.readFile ./KAMP/Line_Purge.cfg)
    (builtins.readFile ./KAMP/Smart_Park.cfg)
  ];
}
