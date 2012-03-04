(****************************************************************
 * Utils ********************************************************)

let (|>) a b = b a

let sentence_from_paragraph para =
  let regexp = Str.regexp "[.?!] " in
  let breaker = "...Next.Sentence..." in
  let replacement_fun s = s ^ breaker in
  Str.global_replace regexp ("\\0" ^ breaker) para
  |> Str.split (Str.regexp (" " ^ breaker))

let para_from_text text =
  let replace_regexp = Str.regexp "\n\n\n" in
  let split_regexp = Str.regexp "\n\n" in
  Str.global_replace replace_regexp "\n\n" text
  |> Str.split split_regexp

let words_list_from_text sentence = 
  let regexp = Str.regexp "[.?!]" in
  let updated_sentence = Str.global_replace regexp " \\0" sentence in
  Str.split (Str.regexp " ") updated_sentence
  |> List.filter (fun w -> w <> "")
  |> List.map (fun w -> Str.global_replace (Str.regexp "\n") "" w)

let rec print_strs = function
  | [] -> ()
  | s::ss -> Printf.printf "'%s'\n" s; print_strs ss

let rec break_into_word_segments word_input n = match word_input with
  | [] -> []
  | _::words -> begin
      let rec take words m = match (words, m) with
        | ([], _) -> []
        | (_, 0) -> []
        | (w::ws, _) -> w :: (take ws (m-1)) in
      (take word_input n) :: (break_into_word_segments words n)
  end



(****************************************************************
 * Functionality ************************************************)

type word = string list

type bank = 
  | WordBank of bank Trie.StringTrie.trie * word list

let empty () = WordBank(Trie.StringTrie.empty (), [])

(* FIXME: Doesn't compile, and doesn't make sense *)
let rec get bank sequence = match sequence with
  | [] -> bank
  | w::ws -> 
      let (count, next_bank) = Trie.StringTrie.get bank w in
      get next_bank ws

let update_for_sequence bank sequence =
  (* break_into_word_segments sequence 5
  |> List.iter (fun words ->
      let existing_value 
      (* Get the existing value *)*)
      

  Printf.printf "Printing from one para:\n";
  List.iter (fun s -> Printf.printf "Training with '%s'\n" s) s

let train bank text = 
  let paras = para_from_text text in
  let material = List.fold_left (fun a p -> (words_list_from_text p) :: a) [] paras in
  List.iter (fun s -> update_for_sequence bank s) material

  

(****************************************************************
 * Tests ********************************************************)

let testTextTransformations () =
  let text = "This is a long text. With sentences.\n\n\nWhat comes next?" in
  let para = "This is a sentence. What comes next? This is what, and this is next." in
  let sentence = "This is a     sentence." in
  (* Exercise functions *)
  let paras = (para_from_text text) in
  let sentences = sentence_from_paragraph para in
  let words = (words_list_from_text sentence) in
  (* Run assertions *)
  (* It screws up on smileys etc, but that will have to be ok *)
  assert (paras = ["This is a long text. With sentences.";"What comes next?"]);
  assert (sentences = ["This is a sentence.";
      "What comes next?";"This is what, and this is next."]);
  assert (words = ["This";"is";"a";"sentence";"."])

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

let test () =
  testTextTransformations ();
  testBreakWordsIntoInsertableElements ()

let runAllTests () = 
  Trie.test ();
  test ()

let _ = 
  runAllTests ();
  let text = "This is my text! I love it, and I think everyone should know what it is like
      to train a writewithme program!" in
  let bank = empty () in
  train bank text

