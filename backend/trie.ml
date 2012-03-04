(*
 * This is an attempt at an implementation of a trie.
 *)

module type TrieSig = sig
  type t
  type b
  val to_list : t -> b list
  val from_list : b list -> t
end

module MakeTrie (Trie : TrieSig) = struct
  open List
  open Trie

  (* ----- *
   * types *
   * ----- *)
  type 'a value = 
    | Value of 'a
    | None

  type 'a trie = Point of 'a value * (b * 'a trie) list


  (* ------------------------ *
   * function implementations *
   * ------------------------ *)

  (* Creates a new and empty trie *)
  let empty () = Point (None, [])

  (* Sets a new element to a trie
   * It requires that the key is an enumerable
   *)
  let find_child key_comp children =
    try find (fun (k, _) -> k = key_comp) children
    with Not_found -> (key_comp, empty ())

  (* adds a new element to the trie *)
  let rec trie_set trie lookup_key new_value = 
    let Point(value, children) = trie in
    match lookup_key with
    | [] -> Point(Value(new_value), children)
    | key::keys ->
        let (_, next_child) = (find_child key children) in
        let other_subchildren = filter (function 
          | (k, _) when k = key -> false
          | _ -> true
        ) children in
        let new_children = 
            (key, trie_set next_child keys new_value) 
            :: other_subchildren in
        Point(value, new_children)

  let set trie key new_value = 
    let lookup_key = to_list key in
    trie_set trie lookup_key new_value

  (* gets an element from the trie *)
  let rec trie_get trie key = 
    let Point(value, children) = trie in
    match key with
    | [] -> (match value with
            | None -> raise Not_found
            | Value(v) -> v)
    | k::ks ->
        let (_, nt) = find_child k children in
        trie_get nt ks

  let get trie key = 
    let lookup_key = to_list key in
    trie_get trie lookup_key

  (*let rec each cb trie =
    let Point(value, children) = trie in
    (match value with
    | None -> ()
    | Value v -> cb v);
    iter (fun (_, nt) -> each cb nt) children*)

  let map fn trie =
    let rec mapper fn trie acc_key =
      let Point(value, children) = trie in
      let mapped_value = (match value with
        | None -> None
        | Value v -> Value(fn ((Trie.from_list acc_key), v))) in
      let mapped_children = map (fun (k, nt) -> (k, mapper fn nt (k :: acc_key))) children in
      Point(mapped_value, mapped_children) in
    mapper fn trie []

  let from_list key_value_list = 
    let trie = empty () in
    let rec adder trie pairs = match pairs with
      | [] -> trie
      | (k,v)::rest -> adder (set trie k v) rest in
    adder trie key_value_list

  let fold fn init_acc trie =
    let rec folder acc trie acc_key =
      let Point(value, children) = trie in
      let new_acc = (match value with
        | None -> acc
        | Value v -> (fn acc ((Trie.from_list acc_key), v))) in
      let fold_fn a el = 
        let (k, nt) = el in
        folder a nt (k :: acc_key) in
      fold_left fold_fn new_acc children
    in
    folder init_acc trie []

  let to_list trie =
    let fold_fn a value = value :: a in
    fold fold_fn [] trie
end

module StringTrieFunctionality = struct
  exception Runtime_exception
  type t = string
  type b = char

  let to_list key = 
    let rec make_list key count acc = match count with
      | 0 -> key.[0] :: acc
      | n -> make_list key (count-1) (key.[n] :: acc) in
    make_list key ((String.length key) - 1) []

  let from_list key_elems = 
    let rec make_string str c_list n =
      match c_list with
      | [] -> str
      | c::cs -> str.[n] <- c; make_string str cs (n-1) in
    let len = List.length(key_elems) in
    let str = String.create len in
    make_string str key_elems (len - 1)

end

module StringTrie = MakeTrie (StringTrieFunctionality)

(* ---------------------------------------------- *
 * runs tests agains the trie to verify behaviour *
 * ---------------------------------------------- *)

let testGetSetStringTrie () = 
  let trie = StringTrie.from_list [("a", 1);("ab", 2);("c", 3)] in
  assert ((StringTrie.get trie "a") = 1);
  assert ((StringTrie.get trie "ab") = 2);
  assert ((StringTrie.get trie "c") = 3);
  let new_trie = (StringTrie.set trie "c" 4) in
  assert ((StringTrie.get new_trie "c") = 4);
  Printf.printf "All StringTrie get/set tests passed\n"

let testMap () =
  let trie = StringTrie.from_list [("a", 1);("b", 2)] in
  let mapped_trie = (StringTrie.map (fun (_k,v) -> v+1) trie) in
  assert ((StringTrie.get mapped_trie "a") = 2);
  assert ((StringTrie.get mapped_trie "b") = 3);
  Printf.printf "All StringTrie map tests passed\n"

let testFold () =
  let trie = StringTrie.from_list [("a", 1);("b", 2)] in
  let fold_fn a (_k,v) = a + v in
  let value = StringTrie.fold fold_fn 0 trie in
  assert (value = 3);
  Printf.printf "All StringTrie fold tests passed\n"

let testToList () =
  let original_list = [("a", 1);("b", 2)] in 
  let trie = StringTrie.from_list original_list in
  let created_list = StringTrie.to_list trie in
  assert (original_list = created_list);
  Printf.printf "All StringTrie to_list tests passed\n"

let test () =
  testGetSetStringTrie ();
  testMap ();
  testFold ();
  testToList ()
