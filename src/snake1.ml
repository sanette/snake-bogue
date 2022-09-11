(* BOGUE version 1 of the snake game.

San Vu Ngoc, 2022

Adapted with minimal changes from an ocaml/javascript version by Florent
   Monnier, http://decapode314.free.fr/re/tut/ocaml-re-tut.html

Version 1: this version uses Sdl_area, and Timemout for animation.

*)

open Tsdl
open Bogue
module W = Widget
module L = Layout
module E = Sdl.Event

let width, height = (640, 480)

type pos = int * int

type game_state = {
  pos_snake: pos;
  seg_snake: pos list;
  dir_snake: [`left | `right | `up | `down];
  pos_fruit: pos;
  game_over: bool;
}

let widget = W.sdl_area ~w:width ~h:height ()
let area = W.get_sdl_area widget

let red = Draw.(opaque red)
let black = Draw.(opaque black)
let green = Draw.(opaque green)
let blue = Draw.(opaque blue)

let fill_rect color (x, y) =
  let open Sdl_area in
  let x, y = to_pixels (x, y) in
  let w, h = to_pixels (20, 20) in
  fill_rectangle area ~color ~w ~h (x, y)
;;

let display_game state =
  let bg_color, snake_color, fruit_color =
    if state.game_over
    then (red, black, green)
    else (black, blue, red)
  in
  (* background *)
  Sdl_area.clear area;
  let w, h = Sdl_area.to_pixels (width, height) in
  Sdl_area.fill_rectangle area ~color:bg_color ~w ~h (0, 0);

  fill_rect fruit_color state.pos_fruit;
  List.iter (fill_rect snake_color) state.seg_snake;
  Sdl_area.update area
;;



let rec pop = function
  | [_] -> []
  | hd :: tl -> hd :: (pop tl)
  | [] -> invalid_arg "pop"


let rec new_pos_fruit seg_snake =
  let new_pos =
    (20 * Random.int 32,
     20 * Random.int 24)
  in
  if List.mem new_pos seg_snake
  then new_pos_fruit seg_snake
  else (new_pos)


let update_state req_dir (
  { pos_snake;
    seg_snake;
    pos_fruit;
    dir_snake;
    game_over;
  } as state) =

  if game_over then state else
  let dir_snake =
    match dir_snake, req_dir with
    | `left, `right -> dir_snake
    | `right, `left -> dir_snake
    | `up, `down -> dir_snake
    | `down, `up -> dir_snake
    | _ -> req_dir
  in
  let pos_snake =
    let x, y = pos_snake in
    match dir_snake with
    | `left  -> (x - 20, y)
    | `right -> (x + 20, y)
    | `up    -> (x, y - 20)
    | `down  -> (x, y + 20)
  in
  let game_over =
    let x, y = pos_snake in
    List.mem pos_snake (pop seg_snake)
    || x < 0 || y < 0
    || x >= width
    || y >= height
  in
  let seg_snake = pos_snake :: seg_snake in
  let seg_snake, pos_fruit =
    if pos_snake = pos_fruit
    then (seg_snake, new_pos_fruit seg_snake)
    else (pop seg_snake, pos_fruit)
  in
  { pos_snake;
    seg_snake;
    pos_fruit;
    dir_snake;
    game_over;
  }


let () =
  Random.self_init ();
  let initial_state = {
    pos_snake = (100, 100);
    seg_snake = [
      (100, 100);
      ( 80, 100);
      ( 60, 100);
    ];
    pos_fruit = (200, 200);
    dir_snake = `right;
    game_over = false;
  } in

  let state = ref initial_state in
  let req_dir = ref !state.dir_snake in

  let keychange_action _area _none ev =
    req_dir :=
      match E.(get ev keyboard_keycode) with
      | x when x = Sdl.K.left -> `left
      | x when x = Sdl.K.up -> `up
      | x when x = Sdl.K.right -> `right
      | x when x = Sdl.K.down -> `down
      | _ -> (!state.dir_snake)
  in

  let rec animate () =
    state := update_state !req_dir !state;
    display_game !state;
    Update.push widget;
    Timeout.add (1000/7) animate |> ignore

  in

  let c = W.connect_main widget widget keychange_action E.[key_down] in
  let layout = L.resident widget in
  let board = Bogue.of_layout ~connections:[c] layout in

  animate ();
  Bogue.run board
;;
