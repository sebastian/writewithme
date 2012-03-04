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

let sentence_from_paragraph para =
  let regexp = Str.regexp "[.?!] " in
  let breaker = "...Next.Sentence..." in
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

let rec take n words = 
  if n = 0 then [] else
  match words with
  | [] -> []
  | w :: ws -> w :: (take (n-1) ws)

let take_random_el_from_list el_list =
  List.nth el_list (Random.int (List.length el_list))


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
  | [] -> 
      let WordBank(_trie, words, _count) = bank in
      take_random_el_from_list words
  | w::ws -> 
      let WordBank(trie, _words, _count) = bank in
      let next_bank = Trie.StringTrie.get trie w in
      get_next_word next_bank ws

let predict_next_word words = 
  let open List in
  let rec get_words = function
    | [] -> raise No_next_word
    | w::ws ->
        try get_next_word !root_bank (w::ws)
        with Not_found -> get_words ws in
  let checkable_words = rev (take (Config.word_depth - 1) (rev words))
  in
  get_words checkable_words

let predict_next n text =
  let rec get_n_words n words = match n with
    | 0 -> []
    | _ -> begin
        let next_word = predict_next_word words in
        let new_words = words @ [next_word] in
        next_word :: (get_n_words (n-1) new_words)
    end
  in
  let words_as_list = words_list_from_text text in
  let predicted_words = get_n_words n words_as_list in
  String.concat " " predicted_words


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

let test () =
  testTextTransformations ();
  testBreakWordsIntoInsertableElements ();
  testUpdateAlongPath ();
  testTrainPredictNextWord ()

let runAllTests () = 
  Trie.test ();
  test ()

let _ = 
  runAllTests ();
