open Lwt

(****************************************************************
 * Type definitions *********************************************)

exception No_next_word

type word = string 
type word_occurrence = int

type bank = 
  | WordBank of bank Trie.StringTrie.trie * word list * word_occurrence


(****************************************************************
 * Utils ********************************************************)

let (|>) a b = b a

let print_string_list string_list = 
  List.iter (fun s -> Printf.printf "--> %s\n" s) string_list

let para_from_text text =
  let open Re_str in
  let replace_regexp = regexp "\n\n\n" in
  let split_regexp = regexp "\n\n" in
  let double_broken_text = global_replace replace_regexp "\n\n" text in
  split split_regexp double_broken_text

let words_list_from_text sentence = 
  let open Re_str in
  let regexp = regexp "[.?!,]" in
  let updated_sentence = global_replace regexp " \\0" sentence in
  split (Re_str.regexp " ") updated_sentence
  |> List.filter (fun w -> w <> "")
  |> List.map (fun w -> global_replace (Re_str.regexp "\n") "" w)

let rec break_into_word_segments word_input n = match word_input with
  | [] -> []
  | _::words -> begin
      let rec take words m = match (words, m) with
        | ([], _) -> []
        | (_, 0) -> []
        | (w::ws, _) -> w :: (take ws (m-1)) in
      (take word_input n) :: (break_into_word_segments words n)
  end

let rec take n words = 
  if n = 0 then [] else
  match words with
  | [] -> []
  | w :: ws -> w :: (take (n-1) ws)

let take_random_el_from_list = function
  | [] -> raise No_next_word
  | next_words -> List.nth next_words (Random.int (List.length next_words))

let remove_unwanted_whitespace text =
  let open Re_str in
  let regexp = regexp " \([.?!,]\)" in
  global_replace regexp "\\1" text

let rec trim_and_capitalize text =
  let open String in
  match text.[0] with
  | ' ' -> trim_and_capitalize (sub text 1 ((length text) - 1))
  | _ -> String.capitalize text

let capitalize clean delim text =
  let open Re_str in
  split (regexp delim) text
  |> List.map (fun s -> trim_and_capitalize s)
  |> String.concat (clean ^ " ")

let make_sensible_cases text =
  text
  |> capitalize "." "\."
  |> capitalize "?" "\?"
  |> capitalize "!" "!"
  |> String.uncapitalize

let strip_quotes text =
  let open Re_str in
  let rxp = regexp "[\"'`]" in
  let rxp_spaces = regexp "  " in
  global_replace rxp "" text
  |> global_replace rxp_spaces " "

let beautify_text text =
  text
  |> remove_unwanted_whitespace
  |> make_sensible_cases
  |> strip_quotes


(****************************************************************
 * Functionality ************************************************)

let empty () = WordBank(Trie.StringTrie.empty (), [], 0)

let root_bank = ref (empty ())
let reset_bank () = root_bank := (empty ())

(*
 * What is stored in the trie?
 * - Bank for subsequent words
 * - The number of times that particular word occurred
 * - A list of the most popular next words
 *)
let most_popular_words trie =
  let open List in
  let bank_list = Trie.StringTrie.to_list trie in
  let word_fn = fun (word, WordBank(_trie, _words, count)) -> (word, count) in
  let word_list = map word_fn bank_list in
  let sort_fn = fun (_w1, c1) (_w2, c2) -> 
    if c1 = c2 then 0 else
    if c1 > c2 then 1 else -1
  in
  let sorted_word_tuples = sort sort_fn word_list in
  let top_word_tuples = take 2 sorted_word_tuples in
  map (fun (word, _count) -> word) top_word_tuples

let rec update_along_path bank sequence = 
  match sequence with
  | [] -> bank
  | w::ws -> 
      let WordBank(trie, _words, count) = bank in
      let next_bank = begin
        try Trie.StringTrie.get trie w
        with Not_found -> empty ()
      end in
      let new_bank = update_along_path next_bank ws in
      let new_trie = Trie.StringTrie.set trie w new_bank in
      let new_words = most_popular_words new_trie in
      WordBank(new_trie, new_words, count + 1)

let update_for_sequence sequence =
  break_into_word_segments sequence Config.word_depth
  |> List.iter (fun words -> root_bank := update_along_path !root_bank words)

let train text = 
  let paras = para_from_text text in
  let material = List.fold_left (fun a p -> (words_list_from_text p) :: a) [] paras in
  List.iter (fun s -> update_for_sequence s) material

let rec get_next_word bank words =
  match words with
  | [] -> begin
      let WordBank(_trie, next_words, _count) = bank in
      try (take_random_el_from_list next_words)
      with No_next_word -> raise Not_found
  end
  | w::ws -> 
      let WordBank(trie, _words, _count) = bank in
      let next_bank = Trie.StringTrie.get trie w in
      get_next_word next_bank ws

let predict_next_word words = 
  let open List in
  let rec get_words = function
    | [] -> raise No_next_word
    | w::ws ->
        try get_next_word (!root_bank) (w::ws)
        with Not_found -> get_words ws in
  let checkable_words = rev (take (Config.word_depth - 1) (rev words))
  in
  get_words checkable_words

let predict_next n text =
  let rec get_n_words n words = 
    match n with
    | 0 -> []
    | _ -> begin
        try 
          let next_word = predict_next_word words in
          let new_words = words @ [next_word] in
          next_word :: (get_n_words (n-1) new_words)
        with No_next_word -> []
    end
  in
  let words_as_list = words_list_from_text text in
  let predicted_words = get_n_words n words_as_list in
  String.concat " " predicted_words


(****************************************************************
 * Runner *******************************************************)

let backlog = 15

let try_close chan =
  catch (fun () -> Lwt_io.close chan)
  (function |_ -> return ())

let init_socket sockaddr = let suck = Lwt_unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  Lwt_unix.setsockopt suck Unix.SO_REUSEADDR true;
  Lwt_unix.bind suck sockaddr;
  Lwt_unix.listen suck backlog;
  suck

let process_accept ~sockaddr ~timeout callback (client,_) =
  (* client is now connected *)
  let inchan = Lwt_io.of_fd Lwt_io.input client in
  let outchan = Lwt_io.of_fd Lwt_io.output client in
  let clisockaddr = Unix.getpeername (Lwt_unix.unix_file_descr client) in
  let srvsockaddr = Unix.getsockname (Lwt_unix.unix_file_descr client) in
  let c = callback ~clisockaddr ~srvsockaddr inchan outchan in
  let events = match timeout with
    | None -> [c]
    | Some t -> [c; (Lwt_unix.sleep (float_of_int t) >> return ()) ] in
  Lwt.pick events >> try_close outchan >> try_close inchan
  
let simple ~sockaddr ~timeout callback =
  let suck = init_socket sockaddr in
  let rec handle_connection () =
     lwt x = Lwt_unix.accept suck in
     let _ =  process_accept ~sockaddr ~timeout callback x in
     handle_connection ()
  in
  handle_connection ()

let trainer ~clisockaddr ~srvsockaddr inchan outchan =
  let open Printf in
  lwt text = Lwt_io.read_line inchan in
  let beautified_text = beautify_text text in
  train beautified_text;
  Lwt_io.write outchan ""

let actuator ~clisockaddr ~srvsockaddr inchan outchan =
  let open Printf in
  lwt text = Lwt_io.read_line inchan in
  let beautified_text = beautify_text text in
  train beautified_text;
  let next = (predict_next 10 text) in
  let beautified_next = beautify_text next in
  eprintf "Got: '%s'. Predicting: %s\n%!" beautified_text beautified_next;
  Lwt_io.write outchan beautified_next
  
let _ =
  let inet_addr = Unix.inet_addr_of_string "0.0.0.0" in
  let sockaddr_train = Lwt_unix.ADDR_INET(inet_addr, 5678) in
  let sockaddr_predict = Lwt_unix.ADDR_INET(inet_addr, 6789) in
  let timeout = None in
  let daemon_t = join [ 
    simple ~sockaddr:sockaddr_predict ~timeout actuator;
    simple ~sockaddr:sockaddr_train ~timeout trainer 
  ]
  in
  Lwt_main.run daemon_t


(****************************************************************
 * Tests ********************************************************)

let testTextTransformations () =
  let text = "This is a long text. With sentences.\n\n\nWhat comes next?" in
  let para = "This is a sentence. What comes next? This is what, and this is next." in
  (* Exercise functions *)
  let p::paras = (para_from_text text) in
  let words = (words_list_from_text p) in
  (* Run assertions *)
  (* It screws up on smileys etc, but that will have to be ok *)
  assert (p::paras = ["This is a long text. With sentences.";"What comes next?"]);
  assert (words = ["This";"is";"a";"long";"text";".";"With";"sentences";"."])

let testBreakWordsIntoInsertableElements () =
  let words = (words_list_from_text "hello kjaere mennesker") in
  let [a;b;c] = (break_into_word_segments words 3) in
  assert (a = ["hello";"kjaere";"mennesker"]);
  assert (b = ["kjaere";"mennesker"]);
  assert (c = ["mennesker"]);
  let [d;e;f] = (break_into_word_segments words 2) in
  assert (d = ["hello";"kjaere"]);
  assert (e = ["kjaere";"mennesker"]);
  assert (f = ["mennesker"])

let testUpdateAlongPath () =
  let text = ["text"] in
  let new_bank = update_along_path (empty ()) text in
  let WordBank(_, words, count) = new_bank in
  assert (words = ["text"]);
  assert (count = 1);
  let more_text = ["text";"more"] in
  let newer_bank = update_along_path new_bank more_text in
  let WordBank(_, words, count) = newer_bank in
  assert (words = ["text"]);
  assert (count = 2);
  Printf.printf "WriteWithMeTraining test passed.\n%!"

let testTrainPredictNextWord () =
  let text = "my friend is best" in
  train text;
  let next_word = predict_next 1 "my friend is" in
  assert (next_word = "best");
  let next_words = predict_next 2 "my friend" in
  assert (next_words = "is best");
  Printf.printf "PredictNextWord test passed.\n%!"

let testRemoveWhiteSpace () =
  let bad_text = "hello . there , what ?" in
  let good_text = remove_unwanted_whitespace bad_text in
  assert (good_text = "hello. there, what?")

let testMakeSensibleCases () =
  let bad_text = "hello, there. what? is! this" in
  let good_text = make_sensible_cases bad_text in
  assert (good_text = "hello, there. What? Is! This")

let testTrimAndCapitalize () =
  let bad_text = "   a" in
  let good_text = trim_and_capitalize bad_text in
  assert (good_text = "A");
  let bad_text = "   sebastian" in
  let good_text = trim_and_capitalize bad_text in
  assert (good_text = "Sebastian")

let testRemoveQuotes () =
  let bad_text = "this \" is ' my ` text" in
  let good_text = strip_quotes bad_text in
  assert (good_text = "this is my text")

let testBeautifyText () =
  (* FIXME: ? It removes special characters from the end 
   * of lines. Maybe that is actually a feature rather
   * than a bug :) *)
  let bad_text = "   a ? what \" the fack . is this" in
  let good_text = beautify_text bad_text in
  assert (good_text = "a? What the fack. Is this")

let test () =
  testTextTransformations ();
  testBreakWordsIntoInsertableElements ();
  testUpdateAlongPath ();
  testTrainPredictNextWord ();
  testRemoveWhiteSpace ();
  testMakeSensibleCases ();
  testTrimAndCapitalize ();
  testRemoveQuotes ();
  testBeautifyText ()

let runAllTests () = 
  Trie.test ();
  test ()

(* let _ = *)
(*   runAllTests () *)
