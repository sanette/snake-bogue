(* BOGUE version 3 of the snake game.

San Vu Ngoc, 2022

Adapted with minimal changes from an ocaml/javascript version by Florent
   Monnier, http://decapode314.free.fr/re/tut/ocaml-re-tut.html

Version 3: this version is more BOGUEsque. The snake is a layout composed of
   several layouts, one for each snake "cell".  A "screen" layout is used to
   capute keyboard. This is more involved than the original version, but open
   doors to many improvements (loading images, animations, etc.).

*)

open Tsdl
open Bogue
module W = Widget
module L = Layout
module E = Sdl.Event

let width, height = (32, 24)
let scale = 20

let snake = L.empty ~w:(scale * width) ~h:(scale * height) ()

type pos = int * int

type game_state = {
  pos_snake: pos;
  seg_snake: pos list;
  snake_cells : L.t list;
  fruit : L.t;
  dir_snake: [`left | `right | `up | `down];
  pos_fruit: pos;
  game_over: bool;
}

let red = Draw.(opaque red)
let black = Draw.(opaque black)
let green = Draw.(opaque green)
let blue = Draw.(opaque blue)

let make_fruit () =
  let fruit_style = Style.(of_bg (color_bg red)) in
  L.resident (W.box ~w:scale ~h:scale ~style:fruit_style ())

let show_cell color layout (x, y) =
  L.setx layout (x*scale);
  L.sety layout (y*scale);
  Box.set_background (L.widget layout |> W.get_box) (Style.color_bg color);
  L.show layout
;;

let display_game state =
  let bg_color, snake_color, fruit_color =
    if state.game_over
    then (red, black, green)
    else (black, blue, red)
  in
  L.set_background snake (Some (L.color_bg bg_color));

  show_cell fruit_color state.fruit state.pos_fruit;
  List.iter2 (show_cell snake_color) state.snake_cells state.seg_snake;
;;


let rec pop = function
  | [_] -> []
  | hd :: tl -> hd :: (pop tl)
  | [] -> invalid_arg "pop"


let rec new_pos_fruit seg_snake =
  let new_pos =
    (Random.int width,
     Random.int height)
  in
  if List.mem new_pos seg_snake
  then new_pos_fruit seg_snake
  else new_pos

let add_cell snake_cells =
  let style = Style.(of_bg (color_bg blue)) in
  let cell = L.resident (W.box ~w:scale ~h:scale ~style ()) in
  let cells = cell :: snake_cells in
  L.set_rooms snake cells;
  cells

let update_state req_dir (
  { pos_snake;
    seg_snake;
    snake_cells;
    fruit;
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
    | `left  -> (x - 1, y)
    | `right -> (x + 1, y)
    | `up    -> (x, y - 1)
    | `down  -> (x, y + 1)
  in
  let game_over =
    let x, y = pos_snake in
    List.mem pos_snake (pop seg_snake)
    || x < 0 || y < 0
    || x >= width
    || y >= height
  in
  let seg_snake = pos_snake :: seg_snake in
  let seg_snake, pos_fruit, snake_cells =
    if pos_snake = pos_fruit
    then (seg_snake, new_pos_fruit seg_snake, add_cell snake_cells)
    else (pop seg_snake, pos_fruit, snake_cells)

  in
  { pos_snake;
    seg_snake;
    snake_cells;
    fruit;
    pos_fruit;
    dir_snake;
    game_over;
  }

let () =
  Random.self_init ();
  let fruit = make_fruit () in
  let initial_state = {
    pos_snake = (5, 5);
    seg_snake = [
      (5, 5);
      (4, 5);
      (3, 5);
    ];
    snake_cells = add_cell @@ add_cell @@ add_cell [];
    fruit;
    pos_fruit = (10, 10);
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

  (* Background *)
  let style = Style.(of_bg (color_bg black)) in
  let w = width * scale in
  let h = height * scale in
  let screen = L.resident (W.box ~w ~h ~style ()) in

  let rec animate () =
    state := update_state !req_dir !state;
    display_game !state;
    Update.push (L.widget screen);
    Timeout.add (1000/7) animate |> ignore

  in

  let area = L.superpose [screen; snake; fruit] in
(* The snake cells layouts will be added to the snake rooms. *)

  let w = L.widget screen in
  let c = W.connect_main w w keychange_action E.[key_down] in
  let board = Bogue.of_layout ~connections:[c] area in

  animate ();
  Bogue.run board
;;
