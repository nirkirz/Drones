# Drones
Implementation of a multi-drones single-target game. The drones and target are managed by co-routines, one co-routine each. The game implemented entirely in Assembly language.

-A 100x100 game board.

-A group of N drones which see the same target from different points of view and from different distance.

-Each drone tries to detect where is the target on the game board, in order to destroy it. Drones may destroy the target only if the target is in drone’s field-of-view, and if the target is no more than some maximal distance from the drone. When the current target is destroyed, some new target appears on the game board in some randomly chosen place. The first drone that destroys T targets is the winner of the game.

-Each drone has three-dimensional position on the game board: coordinate x, coordinate y, and direction (angle from x-axis). Drones move randomly chosen distance in randomly chosen angle from their current place. After each movement, a drone calls mayDestroy(…) function with its new position on the board. mayDestroy(…) function returns TRUE if the caller drone may destroy the target, otherwise returns FALSE. If the current target is destroyed, new target is created at random position on the game board. Drones do not know the coordinates of the target on the board game.

-In order to initialize drones positions we generate a random numbers by using Linear-feedback Shift Register method. -We have a co-routine for the scheduler that manages when to run the other co-routines. A specialized co-routine called the printer prints the current state of the game board.

program flow: The program begins by creating the initial state configuration of drones and the initial state of the target. The program initializes appropriate drones and target, and control is then passed to a scheduler co-routine which decides the appropriate scheduling for the co-routines. The scheduling algorithm for drones is ROUND ROBIN, meaning that co-routines are scheduled in a loop: 1,2,3,…,N,1,2,3,…N,… and so on. The printer co-routine should print the current state of the game board each K steps, where step means an execution step of one drone. The game ends when some drone destroys T targets.
