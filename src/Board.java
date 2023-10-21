import javax.imageio.ImageIO;
import javax.swing.*;
import java.io.IOException;
import java.util.*;
import com.google.common.collect.BiMap;
import com.google.common.collect.HashBiMap;

public class Board {
    int intSqScale = 40;

    JButton[][] btnList2d = new JButton[8][8];

    public static BiMap<Pair<Integer, Integer>, Piece> pieceMap = HashBiMap.create();
    private static boolean isBetween(int a, int b, int c) {
        return a < b && b < c || c < b && b < a;
    }
    private static boolean isBlockingPath(int queenX, int queenY, int targetX, int targetY, int obstacleX, int obstacleY) {
//        //If it's a knight, nothing blocks the path.
//        if (type instanceof Knight){
//            return true;
//        }
        if (obstacleY == targetY && obstacleX == targetX) {
            return true; // Queen or target is blocked by an obstacle
        }
        // Check if the blocking piece is in the path between the queen and the target tile
        if ((obstacleX == queenX && obstacleY == queenY) || (obstacleX == targetX && obstacleY == targetY)) {
            return false; // Queen or target is blocked by an obstacle
        }
        if (queenX == targetX && obstacleX == queenX && ((obstacleY > queenY && obstacleY < targetY) || (obstacleY < queenY && obstacleY > targetY))) {
            return false; // Obstacle is in the queen's vertical path
        }
        if (queenY == targetY && obstacleY == queenY && ((obstacleX > queenX && obstacleX < targetX) || (obstacleX < queenX && obstacleX > targetX))) {
            return false; // Obstacle is in the queen's horizontal path
        }
        if (Math.abs(queenX - targetX) == Math.abs(queenY - targetY) && Math.abs(queenX - obstacleX) == Math.abs(queenY - obstacleY) && Math.abs(targetX - obstacleX) == Math.abs(targetY - obstacleY)) {
            return false; // Obstacle is in the queen's diagonal path
        }

        return true;

    }



    private static boolean canMoveHere(int x, int y, int xView, int yView, ArrayList<Integer> relCheckX, ArrayList<Integer> relCheckY){
        //For every spot run every known blocker by it.
        for (int j = 0; j < relCheckX.size(); j++) {
            if (!isBlockingPath(x, y, xView, yView, relCheckX.get(j), relCheckY.get(j))){
               return false;
            }
        }

        return true;
        //If it is successful for all of these then return yes for that spot and add it to the movementRel
        //Do this by having a method, a for loop, and if statement inside that triggers if isBlockingPath is ever true. this statement returns false if triggered.
        //for loop goes through every relCheck. call the method with the inputs the arraylists of blockers, the current position, and the target spot
        //then if the for loop completes, the method returns a true, and we add that to the list.
    }
    JFrame f = new JFrame();
    public static boolean moveAttempt = false;
    static ImageIcon imgBrown;
    static {
        try {
            imgBrown = new ImageIcon(ImageIO.read(images.gfras("resources/brownsquare.jpg")));
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }
    static ImageIcon imgBeige;
    static {
        try {
            imgBeige = new ImageIcon(ImageIO.read(images.gfras("resources/beigesquare.png")));
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }
    static ImageIcon imgRed;
    static {
        try {
            imgRed = new ImageIcon(ImageIO.read(images.gfras("resources/transquarantRed.png")));
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }
    public static JLayeredPane mainPane = new JLayeredPane();
    private static Piece lastPiece;


    //NEXT BIG STEP: MAKE A SYSTEM TO READ ANY SPOT ON THE BOARD AND IDENTIFY WHICH PIECE IS THERE
    //Do Hashmap.get(x).get(y); This should be a Piece Object, return it.

    //This code runs when a square is clicked. It takes the x and y, stored inside that square.
    static void buttonClick(int x, int y) {
        if (!moveAttempt) {
            //Find what piece is there. This piece will be referred to as clickPiece throughout this code, no matter what type of piece it is.
            Piece clickPiece = pieceMap.get(new Pair<>(x, y));
            //Following code is when a button is clicked and if there is a piece on it. clickPiece references that piece.
            if (clickPiece != null) {
                moveAttempt = true;
                lastPiece = clickPiece;
                //System.out.println(clickPcName);
                //These are variables that represent past coordinates of squares that do have pieces. Used to check line of sight.
                ArrayList<Integer> relCheckX = new ArrayList<>();
                ArrayList<Integer> relCheckY = new ArrayList<>();
                System.out.println(x + ", " + y);

                //Cycles through every clickPiece movement value to find blockers.
                for (int i = 0; i < clickPiece.getMovementAbs().size(); i++) {
                    //Logs all pieces that overlap with the movementAbs inside relCheck x or y.
                    //getMovementAbs gets an array of where that piece goes. get(i) shuffles through every piece in the array. getX/Y get the individual coord points.
                    //Adding x onto the end adds the current coordinate spot to the movement system which is relative to the piece. this makes it relative to the board instead of the piece.
                    int xView = clickPiece.getMovementAbs().get(i).getX() + x;
                    int yView = clickPiece.getMovementAbs().get(i).getY() + y;
                    Piece viewedPiece = pieceMap.get(new Pair<>(xView, yView));
                    if (viewedPiece != null) {
                        //Runs if the coordinate xView,yView is occupied. This means it found a piece that might change overlap or block a spot.
                        relCheckX.add(xView);
                        relCheckY.add(yView);
                        System.out.println("Blocker added at " + xView + "," + yView);
                        //Checks if the piece is the same color as it. Does not add the piece to the target spaces if it is.
                    }
                }
                clickPiece.getMovementRel().clear();
                //Cycles through every movement value with line of sight blockers in mind to register which spots can and cant be moved to.
                for (int i = 0; i < clickPiece.getMovementAbs().size(); i++) {
                    int xView = clickPiece.getMovementAbs().get(i).getX() + x;
                    int yView = clickPiece.getMovementAbs().get(i).getY() + y;
                    if (xView <= 7 && xView >= 0 && yView >= 0 && yView <= 7) {
                            //Checks if its able to go without being blocked or if it's a knight who jumps :)
                            if (canMoveHere(x, y, xView, yView, relCheckX, relCheckY) || (clickPiece.getClass().getName().equals("Knight"))) {
                                //Runs only if the spot we are looking at has a piece
                                if (pieceMap.get(new Pair<>(xView, yView)) != null) {
                                    //For when it does have a piece, it needs to be an enemy piece. Checks this via color.
                                    if (pieceMap.get(new Pair<>(xView, yView)).color != pieceMap.get(new Pair<>(x, y)).color) {
                                        clickPiece.getMovementRel().add(new IntPair(xView, yView));
                                    }
                                } else {
                                    //This makes it aware xView and yView coordinates are blocked.
                                    clickPiece.getMovementRel().add(new IntPair(xView, yView));
                                }
                                //System.out.println("added movement to " + xView + "," + yView);
                            } else {
                                //FUTURE: possibly make units that can hop over walls use this feature. this runs just like other ones but in the else it is specifically blocked spots. one time use stuff ig.
                            }
                    }
                }
                clickPiece.paintRelCoords();
            } else {
                //Happens when clickPiece, the tile clicked, has no piece, and there is no piece trying to move right now. eventually, this should do nothing.
                System.out.println("Blank Space");
            }
        }
        //make the following statement an else if that works for if we are in the second phase of moving a piece
        //the if statement should check if the spot clicked is on the list of possibilites.
        //possibly do a 2 way map for this? or a map that does bool outputs and 2 variable inputs?
        //Basically, we just want to quickly see if this coordinate is a valid movement.
        //if it is, then we run a function built in piece that changes the clickPiece position to the x and y of the second clicked one.
        //this implied we need a way to store original clickPiece when movementAttempt = true. because now we have a new clickPiece. will figure that out in a second.
        //best current idea is a global variable/alias that just gets swapped out everytime a movementAttempt != true happens.
        //Also, we need edge cases to deal with unselecting. if a spot isn't on the valid movements, then we don't move the piece but the graphics and stuff are still cleared and the movementAttempt becomes false again.
        else {
            //No matter what is clicked, the next button after this should be independent. (change this, this is wrong
            moveAttempt = false;
            //effectively like clickPiece from before, but now it clarifies it might not be an actual piece.
            Piece clickTile = pieceMap.get(new Pair<>(x, y));


//            if (moveTruthMap.check(clickTile)){
            //runs if there is no piece here. moves the old piece here.
                if (clickTile == null) {
                    lastPiece.pieceMove(x, y);
                    //Adjust pieceMove to make it adjust the visuals on the board.
                }
                //runs if there is a piece here. should remove the piece and then move the old piece here.
                else {
                    //clickTile.labelIcon.setIcon(null);
                }
//            }

        }
    }
        //Conceptually: I am trying to know which button has been clicked, what piece is on that button, then check the movement of that piece
        //I need a method to check what piece is on any square (Done, the pieceMap)
        //I need a method to check what movement of any piece is. (Not done, alternative was done)
        //Ask object "what's movement" then return those values as an IntPair
        //Add transparent red squares (JPanel) to board on palette layer. All squares affected should be told they are movemementaffected. (Done, kinda. might need to rework) movement affected not done.
        //this means during buttonclick, they don't run any of the other code
    public Board() {

        f.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        javax.swing.ToolTipManager.sharedInstance().setInitialDelay(20);
        images.makeIconTransparent(imgRed);

        for (int j = 0; j < 8; j++) {
            for (int i = 0; i < 8; i++) {
                if ((j % 2 == 0) && (i % 2 == 0)) {
                    //This code creates a margin with the intsqscales that aren't multiplied and are just added
                    //With the ones multiplied by two, those act as alternating colored squares.
                    //The if else statements check what row they are on, and alternates between margins to accommodate
                    final int index = i;
                    final int indey = j;
                    btnList2d[i][j] = new JButton(imgBeige);
                    btnList2d[i][j].setBounds(intSqScale + intSqScale * i, intSqScale + intSqScale * j, intSqScale, intSqScale);
                    btnList2d[i][j].setBorderPainted(false);
                    btnList2d[i][j].addActionListener(e -> buttonClick(index,indey));
                    mainPane.add(btnList2d[i][j], JLayeredPane.DEFAULT_LAYER);
                } else if ((j % 2 != 0) && (i % 2 != 0)) {
                    //These are just slightly modified versions of the first one.
                    final int index = i;
                    final int indey = j;
                    btnList2d[i][j] = new JButton(imgBeige);
                    btnList2d[i][j].setBounds(intSqScale + intSqScale * i, intSqScale + intSqScale * j, intSqScale, intSqScale);
                    btnList2d[i][j].setBorderPainted(false);
                    btnList2d[i][j].addActionListener(e -> buttonClick(index,indey));
                    mainPane.add(btnList2d[i][j], JLayeredPane.DEFAULT_LAYER);
                }
                else if (j % 2 == 0) {
                    final int index = i;
                    final int indey = j;
                    btnList2d[i][j] = new JButton(imgBrown);
                    btnList2d[i][j].setBounds(intSqScale + intSqScale * i, intSqScale + intSqScale * j, intSqScale, intSqScale);
                    btnList2d[i][j].setBorderPainted(false);
                    btnList2d[i][j].addActionListener(e -> buttonClick(index,indey));
                    mainPane.add(btnList2d[i][j], JLayeredPane.DEFAULT_LAYER);
                } else {
                    final int index = i;
                    final int indey = j;
                    btnList2d[i][j] = new JButton(imgBrown);
                    btnList2d[i][j].setBounds(intSqScale + intSqScale * i, intSqScale + intSqScale * j, intSqScale, intSqScale);
                    btnList2d[i][j].setBorderPainted(false);
                    btnList2d[i][j].addActionListener(e -> buttonClick(index,indey));
                    mainPane.add(btnList2d[i][j], JLayeredPane.DEFAULT_LAYER);
                }
                btnList2d[i][j].setToolTipText((i) + "," + (j));
            }
        }
        f.setSize(600, 600);
        f.getContentPane().add(mainPane);
        f.setVisible(true);

        //CREATING THE PIECES
        ArrayList<Pawn> pawnListW = new ArrayList<>();
        ArrayList<Pawn> pawnListB = new ArrayList<>();

//        for(int i = 0; i < 8; i++){
//            //This loop create the 8 pawns at rows 2 and 7
//            pawnListW.add(new Pawn(i, 6, true, "pawnListW" +i));
//            pawnListB.add(new Pawn(i, 1, false, "pawnListB" +i));
//
//        }

        Rook rookW1 = new Rook(0, 7, true, "rookW1");
        Rook rookW2 = new Rook(7, 7, true, "rookW2");
        Knight knightW1 = new Knight(1, 7, true, "knightW1");
        Knight knightW2 = new Knight(6, 7, true, "knightW2");
        Bishop bishopW1 = new Bishop(2, 7, true, "bishopW1");
        Bishop bishopW2 = new Bishop(5, 7, true, "bishopW2");
        King kingW = new King(4, 7, true, "kingW");
        Queen queenW = new Queen(3, 7, true, "queenW");
        Rook rookB1 = new Rook(0, 0, false, "rookB1");
        Rook rookB2 = new Rook(7, 0, false, "rookB2");
        Knight knightB1 = new Knight(1, 0, false, "knightB1");
        Knight knightB2 = new Knight(6, 0, false, "knightB2");
        Bishop bishopB1 = new Bishop(2, 0, false, "bishopB1");
        Bishop bishopB2 = new Bishop(5, 0, false, "bishopB2");
        King kingB = new King(4, 0, false, "kingB");
        Queen queenB = new Queen(3, 0, false, "queenB");

    }


}
