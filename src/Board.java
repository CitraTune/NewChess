import javax.imageio.ImageIO;
import javax.swing.*;
import java.awt.*;
import java.awt.image.BufferedImage;
import java.io.IOException;
import java.io.InputStream;
import java.lang.reflect.Array;
import java.util.*;

public class Board {
    int intSqScale = 40;

    JButton[][] btnList2d = new JButton[8][8];
    static boolean[][] filledList2D = new boolean[8][8];

    public static Map<Pair<Integer, Integer>, Piece> pieceMap = new HashMap<>();
    private static boolean isBetween(int a, int b, int c) {
        return a < b && b < c || c < b && b < a;
    }
    private static boolean isBlockingPath(int queenX, int queenY, int targetX, int targetY, int blockX, int blockY) {
        // Check if the blocking piece is in the path between the queen and the target tile
        if (queenX == targetX) {
            return blockX == queenX && isBetween(queenY, blockY, targetY);
        } else if (queenY == targetY) {
            return blockY == queenY && isBetween(queenX, blockX, targetX);
        } else {
            return Math.abs(queenX - blockX) == Math.abs(queenY - blockY) &&
                    Math.abs(targetX - blockX) == Math.abs(targetY - blockY) &&
                    Math.abs(queenX - blockX) == Math.abs(targetX - blockX);
        }
    }


    private static boolean canMoveHere(int x, int y, int xView, int yView, ArrayList<Integer> relCheckX, ArrayList<Integer> relCheckY){
        //For every spot run every known blocker by it.
        for (int j = 0; j < relCheckX.size(); j++) {
            if (isBlockingPath(x, y, xView, yView, relCheckX.get(j), relCheckY.get(j))){
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
                //clickPcName is just the name. String file. Doesn't actually give the class type.
                String clickPcName = clickPiece.name;
                System.out.println(clickPcName);
                //These are variables that represent past coordinates of squares that do have pieces. Used to check line of sight.
                ArrayList<Integer> relCheckX = new ArrayList<>();
                ArrayList<Integer> relCheckY = new ArrayList<>();
                ArrayList<IntPair> relCheckPairOverlap = new ArrayList<>();
                boolean addCheck = false;
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
                        //As of now, this lets in the piece if it is on the same spot and is the same color. This should not be true. Add system for that to the method.
                        if (canMoveHere(x, y, xView, yView, relCheckX, relCheckY)) {
                                //Make it so we are aware xView and yView coordinates are blocked.
                                clickPiece.getMovementRel().add(new IntPair(xView,yView));
                                //System.out.println("Spot allowed in: " + xView + "," + yView );
                        }
                        else{
                            //System.out.println("Spot blocked: " + xView + "," + yView );
                        }
                    }
                }
                clickPiece.paintRelCoords();
            } else {
                //Happens when clickPiece, the tile clicked, has no piece.
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
        //Also, we need edge cases to deal with unselecting. if a spot isnt on the valid movements, then we dont move the piece but the graphics and stuff are still cleared and the movementAttempt becomes false again.
        else  {

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
                    filledList2D[i][j] = false;
                    mainPane.add(btnList2d[i][j], JLayeredPane.DEFAULT_LAYER);
                } else if ((j % 2 != 0) && (i % 2 != 0)) {
                    //These are just slightly modified versions of the first one.
                    final int index = i;
                    final int indey = j;
                    btnList2d[i][j] = new JButton(imgBeige);
                    btnList2d[i][j].setBounds(intSqScale + intSqScale * i, intSqScale + intSqScale * j, intSqScale, intSqScale);
                    btnList2d[i][j].setBorderPainted(false);
                    btnList2d[i][j].addActionListener(e -> buttonClick(index,indey));
                    filledList2D[i][j] = false;
                    mainPane.add(btnList2d[i][j], JLayeredPane.DEFAULT_LAYER);
                }
                else if (j % 2 == 0) {
                    final int index = i;
                    final int indey = j;
                    btnList2d[i][j] = new JButton(imgBrown);
                    btnList2d[i][j].setBounds(intSqScale + intSqScale * i, intSqScale + intSqScale * j, intSqScale, intSqScale);
                    btnList2d[i][j].setBorderPainted(false);
                    btnList2d[i][j].addActionListener(e -> buttonClick(index,indey));
                    filledList2D[i][j] = false;
                    mainPane.add(btnList2d[i][j], JLayeredPane.DEFAULT_LAYER);
                } else {
                    final int index = i;
                    final int indey = j;
                    btnList2d[i][j] = new JButton(imgBrown);
                    btnList2d[i][j].setBounds(intSqScale + intSqScale * i, intSqScale + intSqScale * j, intSqScale, intSqScale);
                    btnList2d[i][j].setBorderPainted(false);
                    btnList2d[i][j].addActionListener(e -> buttonClick(index,indey));
                    filledList2D[i][j] = false;
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
//            pieceMap.put(new Pair<>(i, 6), pawnListW.get(i));
//            pawnListB.add(new Pawn(i, 1, false, "pawnListB" +i));
//            pieceMap.put(new Pair<>(i, 1), pawnListB.get(i));
//
//        }

        Rook rookW1 = new Rook(0, 7, true, "rookW1");
        pieceMap.put(new Pair<>(0, 7), rookW1);
        Rook rookW2 = new Rook(7, 7, true, "rookW2");
        pieceMap.put(new Pair<>(7, 7), rookW2);
        Knight knightW1 = new Knight(1, 7, true, "knightW1");
        pieceMap.put(new Pair<>(1, 7), knightW1);
        Knight knightW2 = new Knight(6, 7, true, "knightW2");
        pieceMap.put(new Pair<>(6, 7), knightW2);
        Bishop bishopW1 = new Bishop(2, 7, true, "bishopW1");
        pieceMap.put(new Pair<>(2, 7), bishopW1);
        Bishop bishopW2 = new Bishop(5, 7, true, "bishopW2");
        pieceMap.put(new Pair<>(5, 7), bishopW2);
        King kingW = new King(4, 7, true, "kingW");
        pieceMap.put(new Pair<>(4, 7), kingW);
        Queen queenW = new Queen(3, 7, true, "queenW");
        pieceMap.put(new Pair<>(3, 7), queenW);
        Rook rookB1 = new Rook(0, 0, false, "rookB1");
        pieceMap.put(new Pair<>(0, 0), rookB1);
        Rook rookB2 = new Rook(7, 0, false, "rookB2");
        pieceMap.put(new Pair<>(7, 0), rookB2);
        Knight knightB1 = new Knight(1, 0, false, "knightB1");
        pieceMap.put(new Pair<>(1, 0), knightB1);
        Knight knightB2 = new Knight(6, 0, false, "knightB2");
        pieceMap.put(new Pair<>(6, 0), knightB2);
        Bishop bishopB1 = new Bishop(2, 0, false, "bishopB1");
        pieceMap.put(new Pair<>(2, 0), bishopB1);
        Bishop bishopB2 = new Bishop(5, 0, false, "bishopB2");
        pieceMap.put(new Pair<>(5, 0), bishopB2);
        King kingB = new King(4, 0, false, "kingB");
        pieceMap.put(new Pair<>(4, 0), kingB);
        Queen queenB = new Queen(3, 0, false, "queenB");
        pieceMap.put(new Pair<>(3, 0), queenB);

    }


}
