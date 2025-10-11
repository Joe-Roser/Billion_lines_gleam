# Billion Lines Challenge

This is my first billion lines solution, using gleam. I chose gleam because of the simple concurrency and pattern matching, and because I have been really wanting to use it. I love the strong types and the beam combined.

I have enjoyed using the beam, but feel that the gleam implementation is still young. I was unable to get a supervisor to manage the proccess and have just made my code slightly more resilient to compensate. There is lots of documentation but the api seems to have changed a lot recently and I could't find an implementation that would work.

Overall, I have really enjoyed this experiment. The pattern matching and immutability, as well as a focus on recursion has been really refreshing and fun. I will come back to gleam, especially lustre which, even if I hate the html syntax, looks like an amazing framework.


## Structure:
_Streamer_ reads chunks from the file passed and sends to a passed channel. The streamer is responsible for cutting of the final line to make it so each sent chunk is complete.

_Proccessor_ recieves complete data from the streamer and passes it to a child proccess which splits the lines and proccesses each of them, collecting the data it proccessed into a dict and sending it back up to the proccessor to be passed on to the collator.

_Collator_ recives dicts from the proccessor and collates them with a special collision function. When it receives a final message, it formats and outputs the data to the output file.

