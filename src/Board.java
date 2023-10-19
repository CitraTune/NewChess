import javax.swing.*;
import java.awt.*;
import java.awt.image.BufferedImage;
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
    JFrame f = new JFrame();
    public static boolean moveAttempt = false;
    static ImageIcon imgBrown = new ImageIcon("C:\\Users\\awesome22\\Downloads\\brownsquare.png");
    static ImageIcon imgBeige = new ImageIcon("C:\\Users\\awesome22\\Downloads\\beigesquare.png");
    static ImageIcon imgRed = new ImageIcon("C:\\Users\\awesome22\\Downloads\\transquarantRed.png");
    public static JLayeredPane mainPane = new JLayeredPane();

    //Honestly the code below is copied. It just makes a transparent square. Too much effort for something so simple
    private void makeIconTransparent(ImageIcon icon) {
        // Get the image from the ImageIcon
        Image image = icon.getImage();
        // Create a BufferedImage for customizing transparency
        BufferedImage bufferedImage = new BufferedImage(
                icon.getIconWidth(), icon.getIconHeight(), BufferedImage.TYPE_INT_ARGB);
        // Create a Graphics2D object to work with the BufferedImage
        Graphics2D g2d = bufferedImage.createGraphics();
        // Set the transparency using AlphaComposite
        g2d.setComposite(AlphaComposite.getInstance(AlphaComposite.SRC_OVER, (float) 0.5));
        // Draw the original image onto the BufferedImage
        g2d.drawImage(image, 0, 0, null);
        // Dispose of the Graphics2D object
        g2d.dispose();
        // Update the ImageIcon with the modified image
        icon.setImage(bufferedImage);
    }

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
                //Cycles through every movement value with line of sight blockers in mind to register which spots can and cant be moved to.
                for (int i = 0; i < clickPiece.getMovementAbs().size(); i++) {
                    int xView = clickPiece.getMovementAbs().get(i).getX() + x;
                    int yView = clickPiece.getMovementAbs().get(i).getY() + y;
                    if (xView <= 7 && xView >= 0 && yView >= 0 && yView <= 7) {
                        System.out.println("ran at " + xView + "," + yView);
                        for (int j = 0; j < relCheckX.size(); j++) {
                            System.out.println("six numbers compared: x,y,vx,vy,bx,by " + x + "," + y + "," + xView + "," + yView + "," + relCheckX.get(j) + "," + relCheckY.get(j) + "\n isBlocking path is " + isBlockingPath(x, y, xView, yView, relCheckX.get(j), relCheckY.get(j)));
                            if (isBlockingPath(x, y, xView, yView, relCheckX.get(j), relCheckY.get(j))) {
                                //Make it so we are aware xView and yView coordinates are blocked.
                                //Problem: AbsCoords of the piece exist, and rel's exist as well.
                                //However, the goal is to add the abs ones minus the rel ones that face overlap
                                //This is not easy because it's slow to check every abs one if it's an overlap before adding it
                                //And you can't just subtract the intpair from the array of intpairs without polling
                                //And using all xViews that don't get caught by isBlockingPath results in xViews that might get past on other isBlockingPath runs
                                //Although this one seems the most viable as you could put a bunch of && statements and run the isBlockingPaths all at once and drop the for loop and just use increments of relCheckX.size.
                                //Above idea kinda makes sense kinda doesn't.

                                //My plan of attack. For every spot check it with every known blocker.
                                //If it is successful for all blockers then return yes for that spot and add it to the movementRel. Once all spots (on board) are done, paint.
                                //Do this by having a method, a for loop, and if statement inside that triggers if isBlockingPath is ever true. this statement returns false if triggered.
                                //for loop goes through every relCheck. call the method with the inputs the arraylists of blockers, the current position, and the target spot
                                //then if the for loop completes, the method returns a true and we add that to the list.
                            }

                            //Reference for now

//                        movementRel.add(new IntPair(x, y));

//                        if (isBlockingPath(x, y, xView, yView, relCheckX.get(j), relCheckY.get(j))) {
//                            System.out.println("isBlockingPath is true");
//                            clickPiece.getMovementRel().clear();
//                            clickPiece.getMovementRel().add(new IntPair(xView,yView));
//                            clickPiece.paintRelCoords();
//                        }
//                        else{
//                            System.out.println("isBlockingPath is false");
//                        }
                        }
                    }
                }
            } else {
                //Happens when clickPiece, the tile clicked, has no piece.
                System.out.println("Blank Space");
            }
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
        makeIconTransparent(imgRed);

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
