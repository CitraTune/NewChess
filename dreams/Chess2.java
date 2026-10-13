import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;
import javax.swing.*;
import javax.swing.border.EmptyBorder;
import java.awt.*;
import java.awt.event.*;
import java.io.*;
import java.net.*;
import java.net.http.*;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.*;
import java.util.List;
import java.util.concurrent.*;

/**
 * Chess II — AI version with younger me's dreams.
 * JDK 17+, no libraries. Run: java Chess2.java
 * Online: java Chess2.java --host --bind YOUR_TAILSCALE_IP
 * Browser only: java Chess2.java --server --bind 127.0.0.1
 * Tests: java Chess2.java --test
 */
public class Chess2 {
    static final String[] TYPES = {"pawn","knight","bishop","rook","queen","king","frog"};
    static final String[] ICONS = {"♟","♞","♝","♜","♛","♚","♟"};
    static final int[] VALUES = {50,150,150,250,450,500,50};
    static final String[][] PATHS = {{},{ "Dragon","Unicorn" },{ "Necromancer","Divine Cleric" },{ "M1 Abrams","Golem" },{},{},{}};
    static final String[] FUSIONS = {"","Sky Strider","Archmage","Iron Warden","","",""};
    record Def(String id,String name,String target,int cost,String text) {}
    static final List<Def> ITEMS = List.of(
        new Def("shield","Shield","ally",100,"Blocks one direct attack. The attacker spends their turn."),
        new Def("magic","Magic Shield","ally",100,"Blocks one spell or ranged hit."),
        new Def("boots","Flame Boots","ally",180,"Leave fire behind for the next enemy turn."),
        new Def("glass","Glass Armor","ally",130,"Cannot be killed through the next enemy turn."),
        new Def("bleach","Bleach","tile",40,"Remove a mystery tile, banana or hazard."),
        new Def("gas","Gas Bomb","tile",160,"Gas a 3×3 area for 3 rounds. Cannot deploy over enemies."),
        new Def("missile","Heatseeker","enemy",350,"Hit a non-pawn enemy within 5 squares of your queen."),
        new Def("egg","Egg","enemy",70,"Stun an enemy for their next turn."),
        new Def("insurance","Insurance Contract","none",180,"Earn $40 whenever one of your pieces dies."),
        new Def("arm","Robotic Arm","none",160,"Permanently increase your hand limit to 5."),
        new Def("pack","Card Pack","none",100,"Draw 5 cards. Excess oldest cards discarded at turn end."),
        new Def("pawn","Pawn Cannon","empty",100,"Deploy a pawn in your half. It cannot act next turn."),
        new Def("rein","Rein Carnation","ally",220,"On death, summon a replacement pawn nearby."),
        new Def("spider","Spider Sac","queen",170,"On your queen's death, spawn 2 non-promoting pawns."));
    static final List<Def> CARDS = List.of(
        new Def("chacha","Cha-Cha","pawn",0,"Move a pawn one square left if empty."),
        new Def("greed","Pot of Greed","none",0,"Draw 2 cards."),
        new Def("frog","Big Frog","empty",0,"Spawn a frog on your pawn lane. Moves 1–2 forward and promotes."),
        new Def("rat","Rat Hat","ally",0,"Add knight movement this turn."),
        new Def("union","Unionize!","none",0,"Your pawns can advance one extra square this turn."),
        new Def("vest","Homemade Vest","ally",0,"Protect from ranged hits through the next enemy turn."),
        new Def("collector","Collector's Edition","none",0,"Gain $10 for each of your turns held."),
        new Def("traffic","LA Traffic","none",0,"End your turn."),
        new Def("radio","Radio Interference","enemy",0,"Freeze an enemy for their next turn."),
        new Def("eject","Ejector Seat","ally",0,"Move a piece 2 squares backwards if empty."),
        new Def("scissors","Scissors","none",0,"Discard the opponent's oldest card."),
        new Def("ticket","Train Ticket","ally",0,"Move a piece 5 squares forward if empty. Uses your turn."),
        new Def("blanket","Blanket","ally",0,"Conceal a piece's appearance through the next enemy turn."),
        new Def("warp","Time Warp","ally",0,"Return a piece to its original square if empty."),
        new Def("blackhole","Black Hole","tile",0,"Freeze all pieces in a 3×3 area through the next enemy turn."));
    record Pos(int x,int y) {}
    record Card(String id,int born) {}
    record Hazard(String type,int owner,int until) {}
    record Grave(int type,int color) {}
    static class Piece implements Cloneable {
        public Piece clone() throws CloneNotSupportedException {return (Piece)super.clone();}
        int id,type,color,x,y,sx,sy,frozen,armor,rat,vest,blanket,fogTurns,hp=4;
        boolean moved,shield,magic,boots,rein,spider,noPromote;
        String upgrade="",fusion="";
        Piece(int id,int type,int color,int x,int y) {this.id=id;this.type=type;this.color=color;this.x=x;this.y=y;this.sx=x;this.sy=y;}
        String name(){return !fusion.isEmpty()?fusion:!upgrade.isEmpty()?upgrade:TYPES[type];}
        Pos pos(){return new Pos(x,y);}
    }
    static class Player {
        int money=200,limit=3;
        boolean insured;
        List<Card> hand=new ArrayList<>();
        List<String> items=new ArrayList<>();
    }
    static void require(boolean ok,String message){if(!ok)throw new IllegalArgumentException(message);}
    static Def def(List<Def> defs,String id){return defs.stream().filter(d->d.id.equals(id)).findFirst().orElseThrow(()->new IllegalArgumentException("Unknown item."));}
    static String side(int c){return c==0?"Ivory":"Onyx";}
    static String square(int x,int y){return ""+(char)('a'+x)+(y+1);}
    static int distance(int x,int y,int a,int b){return Math.max(Math.abs(x-a),Math.abs(y-b));}
    static class Game implements Cloneable {
        public Game clone() throws CloneNotSupportedException {return (Game)super.clone();}
        boolean campaignBattle;int bountyBonus;
        int size=8,turn=0,ply=0,nextId=1,winner=-1,reveals=0,union=-1,unionPly=-1,freeUsed=-1,shotsId=-1,shots=0;
        boolean shopUnlocked,cardsUnlocked,fog,shopOpen,shopFree;
        Random rng;
        List<Piece> pieces=new ArrayList<>();
        Player[] players={new Player(),new Player()};
        Map<Pos,String> tiles=new LinkedHashMap<>();
        Map<Pos,Hazard> hazards=new LinkedHashMap<>();
        List<String> stock=new ArrayList<>(),log=new ArrayList<>();
        List<Grave> graves=new ArrayList<>();
        Pos lastFrom,lastTo;
        Game(long seed){
            rng=new Random(seed);
            int[] order={3,1,2,4,5,2,1,3};
            for(int x=0;x<8;x++){add(order[x],1,x,0);add(0,1,x,1);add(0,0,x,6);add(order[x],0,x,7);}
            int[][] spots={{1,2},{4,2},{6,2},{0,3},{3,3},{5,4},{2,4},{7,4},{1,5},{4,5},{6,5}};
            for(int[] s:spots)tiles.put(new Pos(s[0],s[1]),"mystery");
            restock();note("Capture armies. Collect relics. Break chess.");
        }
        void note(String s){log.add(0,s);if(log.size()>100)log.remove(100);}
        Piece add(int t,int c,int x,int y){Piece p=new Piece(nextId++,t,c,x,y);pieces.add(p);return p;}
        Piece at(int x,int y){return pieces.stream().filter(p->p.x==x&&p.y==y).findFirst().orElse(null);}
        Piece piece(int id){return pieces.stream().filter(p->p.id==id).findFirst().orElse(null);}
        boolean inside(int x,int y){return x>=0&&y>=0&&x<size&&y<size;}
        boolean empty(int x,int y){return inside(x,y)&&at(x,y)==null;}
        void restock(){
            List<String> pool=new ArrayList<>();
            for(Def d:ITEMS)if(cardsUnlocked||!List.of("arm","pack").contains(d.id))pool.add(d.id);
            Collections.shuffle(pool,rng);stock=new ArrayList<>(pool.subList(0,4));
        }
        void draw(int c,int count,boolean overflow){
            if(!cardsUnlocked)return;
            for(int i=0;i<count;i++)players[c].hand.add(new Card(CARDS.get(rng.nextInt(CARDS.size())).id,ply));
            if(!overflow)trim(c);
        }
        void trim(int c){while(players[c].hand.size()>players[c].limit)players[c].hand.remove(0);}
        void put(Set<Pos> out,Piece p,int x,int y,boolean capture){
            if(!inside(x,y))return;Piece q=at(x,y);
            if(q==null||(capture&&q.color!=p.color))out.add(new Pos(x,y));
        }
        void ray(Set<Pos> out,Piece p,int dx,int dy,int max){
            for(int i=1;i<=max;i++){int x=p.x+dx*i,y=p.y+dy*i;if(!inside(x,y))break;put(out,p,x,y,!p.upgrade.equals("Divine Cleric"));if(at(x,y)!=null)break;}
        }
        static final int[][] JUMPS={{1,2},{2,1},{-1,2},{-2,1},{1,-2},{2,-1},{-1,-2},{-2,-1}};
        void knight(Set<Pos> out,Piece p){for(int[] d:JUMPS)put(out,p,p.x+d[0],p.y+d[1],true);}
        Set<Pos> moves(Piece p){
            Set<Pos> out=new LinkedHashSet<>();
            if(p==null||winner!=-1||p.frozen>ply||shots>0)return out;
            int dir=p.color==0?-1:1;
            if(p.fusion.equals("Sky Strider")){
                for(int y=0;y<size;y++)for(int x=0;x<size;x++)if(x==p.x||y==p.y||Math.abs(x-p.x)==Math.abs(y-p.y))put(out,p,x,y,true);
                knight(out,p);
            }else if(p.fusion.equals("Iron Warden")){
                for(int dx=-2;dx<=2;dx++)for(int dy=-2;dy<=2;dy++)put(out,p,p.x+dx,p.y+dy,true);
            }else if(p.type==0||p.type==6){
                int max=(p.type==6?2:p.moved?1:2)+(union==p.color&&unionPly==ply?1:0);
                for(int i=1;i<=max;i++){if(!empty(p.x,p.y+dir*i))break;out.add(new Pos(p.x,p.y+dir*i));}
                for(int dx:new int[]{-1,1}){Piece q=at(p.x+dx,p.y+dir);if(q!=null&&q.color!=p.color)out.add(q.pos());}
            }else if(p.type==1){
                knight(out,p);
                if(p.upgrade.equals("Dragon"))for(int dx=-1;dx<=1;dx++)ray(out,p,dx,dir,2);
                if(p.upgrade.equals("Unicorn"))for(int[] d:JUMPS)if(empty(p.x+d[0],p.y+d[1]))
                    for(int dx=-1;dx<=1;dx++)for(int dy=-1;dy<=1;dy++)put(out,p,p.x+d[0]+dx,p.y+d[1]+dy,true);
            }else if(p.type==5){
                for(int dx=-1;dx<=1;dx++)for(int dy=-1;dy<=1;dy++)put(out,p,p.x+dx,p.y+dy,true);
            }else{
                if(p.type==3||p.type==4)for(int[] d:new int[][]{{1,0},{-1,0},{0,1},{0,-1}})ray(out,p,d[0],d[1],p.upgrade.equals("Golem")?3:size);
                if(p.type==2||p.type==4)for(int[] d:new int[][]{{1,1},{-1,1},{1,-1},{-1,-1}})ray(out,p,d[0],d[1],size);
            }
            if(p.rat>ply)knight(out,p);
            out.remove(p.pos());return out;
        }
        void spawnNear(int type,int color,int x,int y,int count,boolean noPromote){
            for(int r=1;r<size&&count>0;r++)for(int dy=-r;dy<=r&&count>0;dy++)for(int dx=-r;dx<=r&&count>0;dx++)
                if(Math.max(Math.abs(dx),Math.abs(dy))==r&&empty(x+dx,y+dy)){add(type,color,x+dx,y+dy).noPromote=noPromote;count--;}
        }
        boolean hit(Piece victim,Piece attacker,boolean ranged){
            if(victim.armor>ply||(ranged&&victim.vest>ply)){note("Armor protects "+victim.name()+".");return false;}
            if(ranged&&victim.magic){victim.magic=false;note("Magic shield shattered.");return false;}
            if(!ranged&&victim.shield){victim.shield=false;note("Shield shattered. Attack spent.");return false;}
            if(!ranged&&victim.fusion.equals("Iron Warden")){note("Iron Warden resists direct attacks.");return false;}
            if(!ranged&&victim.upgrade.equals("Golem")&&attacker!=null&&distance(victim.x,victim.y,attacker.x,attacker.y)>2){note("Golem resists a distant attack.");return false;}
            if(victim.fusion.equals("Iron Warden")&&victim.hp>1){victim.hp--;note("Iron Warden: "+victim.hp+" armor remaining.");return false;}
            pieces.remove(victim);graves.add(new Grave(victim.type,victim.color));
            if(attacker!=null&&attacker.color!=victim.color){players[attacker.color].money+=VALUES[victim.type]+(attacker.color==0?bountyBonus:0);note(side(attacker.color)+" captures "+victim.name()+" · +$"+VALUES[victim.type]+(victim.type==5?" — the battle continues!":""));}
            else note(victim.name()+" falls.");
            if(players[victim.color].insured)players[victim.color].money+=40;
            if(victim.rein)spawnNear(0,victim.color,victim.x,victim.y,1,false);
            if(victim.spider)spawnNear(0,victim.color,victim.x,victim.y,2,true);
            if(attacker!=null&&attacker.upgrade.equals("Necromancer"))spawnNear(0,attacker.color,attacker.x,attacker.color==0?size-1:0,2,false);
            return true;
        }
        void victory(){
            boolean a=pieces.stream().anyMatch(p->p.color==0),b=pieces.stream().anyMatch(p->p.color==1);
            if(!a||!b){winner=a?0:b?1:2;note(winner==2?"Both armies fell. Draw.":side(winner)+" wins by army elimination!");shopOpen=false;}
        }
        void end(){
            if(fog)for(Piece p:new ArrayList<>(pieces))if(p.color==turn){
                if(p.y==size/2||p.y==size/2-1){if(++p.fogTurns>=2)hit(p,null,true);}else p.fogTurns=0;
            }
            trim(turn);ply++;turn=1-turn;shopOpen=false;freeUsed=-1;shots=0;shotsId=-1;
            hazards.entrySet().removeIf(e->e.getValue().until<=ply);
            if(ply==38&&size==8&&!campaignBattle)expand();
            victory();if(winner==-1)draw(turn,1,false);
        }
        Pos expanded(Pos p){return new Pos(p.x+6,p.y<4?p.y+2:p.y+10);}
        void expand(){
            for(Piece p:pieces){Pos a=expanded(p.pos()),b=expanded(new Pos(p.sx,p.sy));p.x=a.x;p.y=a.y;p.sx=b.x;p.sy=b.y;}
            Map<Pos,String> t=new LinkedHashMap<>();tiles.forEach((k,v)->t.put(expanded(k),v));tiles=t;
            Map<Pos,Hazard> h=new LinkedHashMap<>();hazards.forEach((k,v)->h.put(expanded(k),v));hazards=h;
            if(lastFrom!=null)lastFrom=expanded(lastFrom);if(lastTo!=null)lastTo=expanded(lastTo);
            size=20;for(int i=0;i<30;i++){Pos p=new Pos(rng.nextInt(20),rng.nextInt(20));if(empty(p.x,p.y))tiles.put(p,"mystery");}
            note("EXPANSION · the battlefield becomes 20 × 20.");
        }
        void event(Piece p){
            reveals++;
            String[] pool={"shield","harvest","freeze","hypnosis","morph","spider","election","magic","treasure","fog"};
            String e=reveals==1?"shop":reveals==2?"cards":pool[rng.nextInt(pool.length)];
            switch(e){
                case "shop" -> {shopUnlocked=true;restock();note("THE BAZAAR AWAKENS · shop unlocked.");}
                case "cards" -> {cardsUnlocked=true;draw(0,2,false);draw(1,2,false);note("CARD GAME · both armies draw two.");}
                case "shield" -> {p.shield=true;note("A Shield protects "+p.name()+".");}
                case "magic" -> {p.magic=true;note("Magic Shield bestowed.");}
                case "freeze" -> {p.frozen=ply+7;note("Break a Leg · frozen for 3 of your turns.");}
                case "hypnosis" -> {players[p.color].money+=VALUES[p.type];p.color=1-p.color;note("Hypnotism · allegiance changes; former owner compensated.");}
                case "morph" -> {int[][] options={{1,2},{0,2},{1,3},{2,4},{3},{4},{0}};p.type=options[p.type][rng.nextInt(options[p.type].length)];p.upgrade="";p.fusion="";note("Transmogrify · now a "+p.name()+".");}
                case "spider" -> {Piece q=pieces.stream().filter(v->v.color==p.color&&v.type==4).findFirst().orElse(null);if(q!=null){q.spider=true;note("Spider Sac given to your queen.");}else{players[p.color].money+=50;note("No queen: +$50 instead.");}}
                case "treasure" -> {players[p.color].money+=100;players[p.color].items.add("shield");note("Buried treasure · $100 and a Shield.");}
                case "election" -> {for(int[] d:new int[][]{{1,0},{-1,0},{0,1},{0,-1}})if(empty(p.x+d[0],p.y+d[1]))add(0,1-p.color,p.x+d[0],p.y+d[1]);note("Election Rigging · enemy pawns surround you.");}
                case "harvest" -> {List<Pos> empty=new ArrayList<>();for(int y=0;y<size;y++)for(int x=0;x<size;x++)if(empty(x,y)&&!tiles.containsKey(new Pos(x,y)))empty.add(new Pos(x,y));Collections.shuffle(empty,rng);for(int i=0;i<Math.min(10,empty.size());i++)tiles.put(empty.get(i),"banana");note("Bountiful Harvest · bananas are worth $10.");}
                case "fog" -> {fog=true;note("Curse of the Fog · leave the middle two ranks before your second turn ends there.");}
            }
        }
        void land(Piece p){
            if((p.type==0||p.type==6)&&!p.noPromote&&p.y==(p.color==0?0:size-1)){p.type=4;note(side(p.color)+" promotes to queen.");}
            String tile=tiles.remove(p.pos());
            if("banana".equals(tile)){players[p.color].money+=10;note("Harvest · +$10.");}
            if("mystery".equals(tile))event(p);
            Hazard h=hazards.get(p.pos());
            if(h!=null&&h.until>ply&&(h.type.equals("fire")||h.owner!=p.color))hit(p,null,true);
        }
        void move(int id,int x,int y){
            Piece p=piece(id);
            require(!shopOpen&&p!=null&&p.color==turn&&moves(p).contains(new Pos(x,y)),"That move is unavailable.");
            Piece q=at(x,y);
            if(q!=null&&!hit(q,p,false)){end();return;}
            lastFrom=p.pos();lastTo=new Pos(x,y);
            if(p.boots)hazards.put(p.pos(),new Hazard("fire",p.color,ply+2));
            p.x=x;p.y=y;p.moved=true;
            note(side(p.color)+" · "+p.name()+" → "+square(x,y));land(p);end();
        }
        boolean target(String target,int x,int y){
            if(target.equals("none"))return true;
            if(!inside(x,y))return false;Piece p=at(x,y);
            return switch(target){
                case "tile"->true;case "empty"->p==null;case "enemy"->p!=null&&p.color!=turn;
                case "ally"->p!=null&&p.color==turn;case "pawn"->p!=null&&p.color==turn&&p.type==0;
                case "queen"->p!=null&&p.color==turn&&p.type==4;default->false;};
        }
        void teleport(Piece p,int x,int y){
            require(empty(x,y),"The destination must be on the board and empty.");
            require(p.frozen<=ply,"Frozen pieces cannot be relocated.");
            p.x=x;p.y=y;p.moved=true;land(p);
        }
        void use(boolean card,int index,int x,int y){
            require(!shopOpen&&shots==0,"Finish your shop visit or cannon sequence first.");
            Player pl=players[turn];
            require(index>=0&&index<(card?pl.hand.size():pl.items.size()),"That card or relic is no longer available.");
            Card held=card?pl.hand.get(index):null;
            String id=card?held.id:pl.items.get(index);Def d=def(card?CARDS:ITEMS,id);
            require(target(d.target,x,y),"Choose target: "+d.target+".");
            Piece p=at(x,y);int dir=turn==0?-1:1;boolean ends=false;
            if(card)switch(id){
                case "chacha"->teleport(p,p.x-1,p.y);
                case "eject"->teleport(p,p.x,p.y-dir*2);
                case "ticket"->{teleport(p,p.x,p.y+dir*5);ends=true;}
                case "warp"->teleport(p,p.sx,p.sy);
                case "frog"->{int rank=size==8?(turn==0?6:1):(turn==0?16:3);require(y==rank,"Choose your pawn lane: rank "+(rank+1)+".");add(6,turn,x,y);}
                case "rat"->p.rat=ply+1;
                case "union"->{union=turn;unionPly=ply;}
                case "vest"->p.vest=ply+2;
                case "collector"->pl.money+=10*((ply-held.born)/2);
                case "radio"->p.frozen=ply+2;
                case "blanket"->p.blanket=ply+2;
                case "blackhole"->{for(Piece q:pieces)if(distance(x,y,q.x,q.y)<=1)q.frozen=ply+2;}
                case "scissors"->{if(!players[1-turn].hand.isEmpty())players[1-turn].hand.remove(0);}
                case "traffic"->ends=true;
            }
            else switch(id){
                case "shield"->p.shield=true;case "magic"->p.magic=true;case "boots"->p.boots=true;
                case "glass"->p.armor=ply+2;case "egg"->p.frozen=ply+2;
                case "rein"->p.rein=true;case "spider"->p.spider=true;
                case "insurance"->pl.insured=true;case "arm"->pl.limit=5;
                case "bleach"->{tiles.remove(new Pos(x,y));hazards.remove(new Pos(x,y));}
                case "gas"->{
                    require(pieces.stream().noneMatch(q->q.color!=turn&&distance(x,y,q.x,q.y)<=1),"Gas cannot deploy over enemies.");
                    for(int dx=-1;dx<=1;dx++)for(int dy=-1;dy<=1;dy++)if(inside(x+dx,y+dy))hazards.put(new Pos(x+dx,y+dy),new Hazard("gas",turn,ply+6));
                }
                case "missile"->{
                    Piece queen=pieces.stream().filter(q->q.color==turn&&q.type==4&&distance(x,y,q.x,q.y)<=5).findFirst().orElse(null);
                    require(queen!=null&&p.type!=0&&p.type!=6,"Choose a non-pawn enemy within 5 squares of your queen.");hit(p,queen,true);
                }
                case "pawn"->{require(turn==0?y>=size/2:y<size/2,"Deploy in your own half.");add(0,turn,x,y).frozen=ply+3;}
            }
            if(card)pl.hand.remove(held);else pl.items.remove(index);
            if(id.equals("greed"))draw(turn,2,false);
            if(id.equals("pack"))draw(turn,5,true);
            note(side(turn)+" plays "+d.name+".");victory();if(ends&&winner==-1)end();
        }
        void openShop(){
            require(shopUnlocked&&!shopOpen&&shots==0,"The Bazaar is unavailable.");
            shopOpen=true;shopFree=(ply/2+1)%5==0&&freeUsed!=ply;
        }
        void closeShop(){require(shopOpen,"No shop visit is open.");shopOpen=false;if(shopFree)freeUsed=ply;else end();}
        void buy(String id){
            Def d=def(ITEMS,id);Player p=players[turn];
            require(shopOpen&&stock.contains(id)&&p.money>=d.cost,"That purchase is unavailable or too expensive.");
            p.money-=d.cost;p.items.add(id);stock.remove(id);if(stock.isEmpty())restock();note(side(turn)+" buys "+d.name+".");end();
        }
        void upgrade(int id,String path){
            Piece p=piece(id);require(shopOpen&&p!=null&&p.color==turn&&p.upgrade.isEmpty()&&p.fusion.isEmpty()&&Arrays.asList(PATHS[p.type]).contains(path)&&players[turn].money>=250,"Upgrade requires an eligible piece and $250.");
            p.upgrade=path;players[turn].money-=250;note(path+" joins "+side(turn)+".");end();
        }
        void fuse(int type,int x,int y){
            require(type>=1&&type<=3&&shopOpen&&empty(x,y)&&y==(turn==0?size-1:0)&&players[turn].money>=500,"Fusion needs $500 and an empty back-rank square.");
            List<Piece> pair=new ArrayList<>();
            for(String path:PATHS[type]){Piece p=pieces.stream().filter(q->q.color==turn&&q.type==type&&q.upgrade.equals(path)&&q.fusion.isEmpty()).findFirst().orElse(null);require(p!=null,"You need both distinct upgrade paths.");pair.add(p);}
            pieces.removeAll(pair);Piece p=add(type,turn,x,y);p.fusion=FUSIONS[type];players[turn].money-=500;note("ALIGNATION · "+p.fusion+" rises.");end();
        }
        void ability(int id,String ability,int x,int y,int graveIndex){
            Piece p=piece(id);require(!shopOpen&&p!=null&&p.color==turn&&p.frozen<=ply,"Select an active friendly piece.");
            if(ability.equals("shoot")){
                int range=p.fusion.equals("Archmage")?3:p.fusion.equals("Iron Warden")?2:p.upgrade.equals("M1 Abrams")?1:0;
                Piece q=at(x,y);
                require(range>0&&q!=null&&q.color!=turn&&distance(x,y,p.x,p.y)<=range&&(!p.fusion.equals("Archmage")||x==p.x||y==p.y)&&(shots==0||shotsId==id),"Choose an enemy within this weapon's range.");
                hit(q,p,true);note(p.name()+" fires at "+square(x,y)+".");victory();
                if(winner==-1){if(p.fusion.equals("Iron Warden")&&shots==0){shots=1;shotsId=id;note("Iron Warden may fire once more, or end the turn.");}else end();}
                return;
            }
            require(shots==0,"Finish the cannon sequence first.");
            if(ability.equals("summon")){
                require(p.fusion.equals("Archmage")&&empty(x,y)&&distance(x,y,p.x,p.y)<=1,"Summon a pawn on an empty surrounding square.");add(0,turn,x,y);note("Archmage summons a pawn.");end();
            }else if(ability.equals("teleport")){
                require(p.fusion.equals("Archmage")&&distance(x,y,p.x,p.y)>5,"Warp to an empty square more than 5 tiles away.");teleport(p,x,y);note("Archmage warps.");end();
            }else if(ability.equals("revive")){
                require(p.upgrade.equals("Divine Cleric")&&graveIndex>=0&&graveIndex<graves.size(),"Select a fallen ally.");
                Grave dead=graves.get(graveIndex);int price=(VALUES[dead.type]+1)/2;
                require(dead.color==turn&&empty(x,y)&&distance(x,y,p.x,p.y)<=2&&players[turn].money>=price,"Revive an ally within 2 squares for half its base value.");
                players[turn].money-=price;graves.remove(graveIndex);add(dead.type,turn,x,y).moved=true;note("Divine Cleric restores a "+TYPES[dead.type]+".");end();
            }else throw new IllegalArgumentException("Unknown ability.");
        }
        void action(Map<String,String> a){
            require(winner==-1,"This battle has ended. Start a new run to play again.");
            String op=a.getOrDefault("op","");
            switch(op){
                case "move"->move(num(a,"id"),num(a,"x"),num(a,"y"));
                case "card","item"->use(op.equals("card"),num(a,"index"),num(a,"x"),num(a,"y"));
                case "pass"->{require(!shopOpen,"Leave the Bazaar first.");note(side(turn)+" ends the turn.");end();}
                case "shop"->openShop();case "leave"->closeShop();
                case "buy"->buy(a.getOrDefault("item",""));
                case "reroll"->{require(shopOpen&&players[turn].money>=25,"Refresh costs $25.");players[turn].money-=25;restock();}
                case "upgrade"->upgrade(num(a,"id"),a.getOrDefault("path",""));
                case "fuse"->fuse(num(a,"type"),num(a,"x"),num(a,"y"));
                case "ability"->ability(num(a,"id"),a.getOrDefault("ability",""),num(a,"x"),num(a,"y"),num(a,"grave"));
                default->throw new IllegalArgumentException("Unknown action.");
            }
        }
        boolean valid(){
            Set<Pos> seen=new HashSet<>();Set<Integer> ids=new HashSet<>();
            for(Piece p:pieces)if(!inside(p.x,p.y)||!seen.add(p.pos())||!ids.add(p.id)||p.type<0||p.type>6||p.color<0||p.color>1)return false;
            return players[0].money>=0&&players[1].money>=0;
        }
    }
    static int num(Map<String,String> a,String key){try{return Integer.parseInt(a.getOrDefault(key,"-1"));}catch(NumberFormatException e){throw new IllegalArgumentException("Invalid number: "+key);}}
    static Map<String,String> args(String... pairs){Map<String,String> a=new LinkedHashMap<>();for(int i=0;i<pairs.length;i+=2)a.put(pairs[i],pairs[i+1]);return a;}
    static String json(Object o){
        if(o==null)return "null";if(o instanceof Number||o instanceof Boolean)return o.toString();
        if(o instanceof Map<?,?> m){List<String> entries=new ArrayList<>();m.forEach((k,v)->entries.add(json(k.toString())+":"+json(v)));return "{"+String.join(",",entries)+"}";}
        if(o instanceof Collection<?> c){List<String> values=new ArrayList<>();for(Object v:c)values.add(json(v));return "["+String.join(",",values)+"]";}
        String s=o.toString();StringBuilder b=new StringBuilder("\"");
        for(char c:s.toCharArray())switch(c){case '"'->b.append("\\\"");case '\\'->b.append("\\\\");case '\n'->b.append("\\n");case '\r'->b.append("\\r");case '\t'->b.append("\\t");default->{if(c<32)b.append(String.format("\\u%04x",(int)c));else b.append(c);}}
        return b.append('"').toString();
    }
    static Map<String,Object> map(Object... a){Map<String,Object> m=new LinkedHashMap<>();for(int i=0;i<a.length;i+=2)m.put(a[i].toString(),a[i+1]);return m;}
    static String effects(Game g,Piece p){
        List<String> a=new ArrayList<>();if(p.shield)a.add("Shield");if(p.magic)a.add("Magic shield");if(p.boots)a.add("Flame boots");if(p.rein)a.add("Rebirth");if(p.spider)a.add("Spider sac");if(p.frozen>g.ply)a.add("Frozen");if(p.armor>g.ply)a.add("Invulnerable");if(p.rat>g.ply)a.add("Knight movement");if(p.vest>g.ply)a.add("Ranged armor");if(p.noPromote)a.add("No promotion");if(p.fusion.equals("Iron Warden"))a.add(p.hp+" armor");return String.join(" · ",a);
    }

    enum Skill {
        EASY(0,0,0), NORMAL(1,8,400), HARD(2,6,800), EXPERT(3,5,1400);
        final int depth,width,millis;
        Skill(int d,int w,int m){depth=d;width=w;millis=m;}
        static Skill parse(String s){try{return valueOf(s.toUpperCase(Locale.ROOT));}catch(Exception e){throw new IllegalArgumentException("Difficulty: easy, normal, hard or expert.");}}
    }
    record Choice(Map<String,String> action,Game after,double order) {}
    static class Bot {
        final Skill skill;final Random random;long until;int nodes;
        Bot(Skill s,long seed){skill=s;random=new Random(seed);}
        static Game copy(Game g){
            try {
                Game c=(Game)g.clone();
                c.pieces=new ArrayList<>();for(Piece p:g.pieces)c.pieces.add((Piece)p.clone());
                c.players=new Player[2];for(int i=0;i<2;i++){Player p=g.players[i],q=new Player();q.money=p.money;q.limit=p.limit;q.insured=p.insured;q.hand=new ArrayList<>(p.hand);q.items=new ArrayList<>(p.items);c.players[i]=q;}
                c.tiles=new LinkedHashMap<>(g.tiles);c.hazards=new LinkedHashMap<>(g.hazards);c.stock=new ArrayList<>(g.stock);c.graves=new ArrayList<>(g.graves);c.log=new ArrayList<>(g.log);
                // Search never copies the real random generator or predicts unrevealed tiles.
                c.rng=new Random(0);return c;
            }catch(CloneNotSupportedException e){throw new AssertionError(e);}
        }
        static double value(Piece p){return VALUES[p.type]+(!p.upgrade.isEmpty()?100:0)+(!p.fusion.isEmpty()?400:0)+(p.shield?40:0)+(p.magic?20:0)+(p.boots?35:0);}
        static double evaluate(Game g,int color){
            if(g.winner!=-1)return g.winner==color?100000:g.winner==2?0:-100000;
            double score=0;
            for(Piece p:g.pieces){
                double forward=p.color==0?g.size-1-p.y:p.y;
                int nearest=g.size;
                for(Piece q:g.pieces)if(q.color!=p.color)nearest=Math.min(nearest,distance(p.x,p.y,q.x,q.y));
                double position=(p.type==0||p.type==6?forward*3:0)+(g.size-nearest)*1.5-(p.frozen>g.ply?15:0);
                score+=(p.color==color?1:-1)*(value(p)+position);
            }
            // Hand identities are deliberately excluded; only public hand counts matter.
            return score+(g.players[color].money-g.players[1-color].money)*.12+(g.players[color].hand.size()-g.players[1-color].hand.size())*3+(g.players[color].items.size()-g.players[1-color].items.size())*12;
        }
        static List<Map<String,String>> movement(Game g){
            List<Map<String,String>> a=new ArrayList<>();
            for(Piece p:g.pieces)if(p.color==g.turn){
                for(Pos m:g.moves(p))a.add(args("op","move","id",""+p.id,"x",""+m.x,"y",""+m.y));
                if(p.frozen<=g.ply&&(p.upgrade.equals("M1 Abrams")||!p.fusion.isEmpty()))
                    for(Piece q:g.pieces)if(q.color!=p.color&&distance(p.x,p.y,q.x,q.y)<=3)a.add(args("op","ability","id",""+p.id,"ability","shoot","x",""+q.x,"y",""+q.y));
                if(p.frozen<=g.ply&&p.fusion.equals("Archmage")&&g.shots==0){
                    for(int dx=-1;dx<=1;dx++)for(int dy=-1;dy<=1;dy++)if(g.empty(p.x+dx,p.y+dy))a.add(args("op","ability","id",""+p.id,"ability","summon","x",""+(p.x+dx),"y",""+(p.y+dy)));
                    for(Piece q:g.pieces)if(q.color!=p.color)for(int dx=-1;dx<=1;dx++)for(int dy=-1;dy<=1;dy++)if(g.empty(q.x+dx,q.y+dy)&&distance(p.x,p.y,q.x+dx,q.y+dy)>5)a.add(args("op","ability","id",""+p.id,"ability","teleport","x",""+(q.x+dx),"y",""+(q.y+dy)));
                }
                if(p.frozen<=g.ply&&p.upgrade.equals("Divine Cleric")&&g.shots==0)
                    for(int i=0;i<g.graves.size();i++)if(g.graves.get(i).color==g.turn&&g.players[g.turn].money>=(VALUES[g.graves.get(i).type]+1)/2){
                        outer:for(int dx=-2;dx<=2;dx++)for(int dy=-2;dy<=2;dy++)if(g.empty(p.x+dx,p.y+dy)){a.add(args("op","ability","id",""+p.id,"ability","revive","grave",""+i,"x",""+(p.x+dx),"y",""+(p.y+dy)));break outer;}
                    }
            }
            a.add(args("op","pass"));return a;
        }
        static void consumables(Game g,List<Map<String,String>> actions){
            if(g.shots>0)return;
            Player player=g.players[g.turn];
            for(boolean card:new boolean[]{true,false})for(int i=0;i<(card?player.hand.size():player.items.size());i++){
                Def d=def(card?CARDS:ITEMS,card?player.hand.get(i).id:player.items.get(i));
                // Avoid voluntary skips, concealment, and irrelevant movement churn.
                if(List.of("traffic","blanket").contains(d.id))continue;
                if(d.target.equals("none")){actions.add(args("op",card?"card":"item","index",""+i));continue;}
                List<Pos> targets=new ArrayList<>();
                if(List.of("ally","enemy","pawn","queen").contains(d.target))for(Piece p:g.pieces)if(g.target(d.target,p.x,p.y))targets.add(p.pos());
                if(d.target.equals("empty")){
                    int rank=g.size==8?(g.turn==0?6:1):(g.turn==0?16:3);
                    for(int x=0;x<g.size;x++)if(g.empty(x,rank))targets.add(new Pos(x,rank));
                }
                if(d.target.equals("tile")){
                    targets.addAll(g.hazards.keySet());
                    for(Piece p:g.pieces)if(p.color!=g.turn){targets.add(p.pos());for(int dx:new int[]{-2,2})if(g.inside(p.x+dx,p.y))targets.add(new Pos(p.x+dx,p.y));}
                    targets.add(new Pos(g.size/2,g.size/2));
                }
                for(Pos t:new LinkedHashSet<>(targets))actions.add(args("op",card?"card":"item","index",""+i,"x",""+t.x,"y",""+t.y));
            }
        }
        List<Choice> candidates(Game g,boolean prepare){
            List<Map<String,String>> actions=movement(g);if(prepare)consumables(g,actions);
            List<Choice> choices=new ArrayList<>();
            for(Map<String,String> action:actions){
                if(Thread.currentThread().isInterrupted())break;
                Game c=copy(g);c.tiles.entrySet().removeIf(e->e.getValue().equals("mystery"));
                try{c.action(action);double score=evaluate(c,g.turn);
                    if(action.get("op").equals("pass"))score-=8;
                    if(action.get("op").equals("move")&&"mystery".equals(g.tiles.get(new Pos(num(action,"x"),num(action,"y")))))score+=5;
                    choices.add(new Choice(action,c,score));
                }catch(IllegalArgumentException ignored){}
            }
            choices.sort(Comparator.comparingDouble(Choice::order).reversed());return choices;
        }
        double search(Game g,int color,int depth){
            if(depth==0||g.winner!=-1||System.nanoTime()>until||nodes++>900||Thread.currentThread().isInterrupted())return evaluate(g,color);
            List<Choice> choices=candidates(g,false);if(choices.isEmpty())return evaluate(g,color);
            boolean max=g.turn==color;double best=max?-1e9:1e9;
            for(int i=0;i<Math.min(skill.width,choices.size());i++){
                double v=search(choices.get(i).after,color,depth-1);best=max?Math.max(best,v):Math.min(best,v);
                if(System.nanoTime()>until)break;
            }
            return best;
        }
        Map<String,String> choose(Game g,boolean prepare){
            if(g.shopOpen){
                Piece up=g.pieces.stream().filter(p->p.color==g.turn&&PATHS[p.type].length>0&&p.upgrade.isEmpty()&&p.fusion.isEmpty()).findFirst().orElse(null);
                if(up!=null&&g.players[g.turn].money>=250)return args("op","upgrade","id",""+up.id,"path",PATHS[up.type][skill.ordinal()%2]);
                for(String id:g.stock){Def d=def(ITEMS,id);if(g.players[g.turn].money>=d.cost)return args("op","buy","item",id);}
                return args("op","leave");
            }
            if(prepare&&skill!=Skill.EASY&&g.shopUnlocked&&g.shots==0&&g.players[g.turn].money>=350&&g.pieces.stream().anyMatch(p->p.color==g.turn&&PATHS[p.type].length>0&&p.upgrade.isEmpty()&&p.fusion.isEmpty()))return args("op","shop");
            until=System.nanoTime()+skill.millis*1_000_000L;nodes=0;
            List<Choice> choices=candidates(g,prepare&&skill!=Skill.EASY);
            if(choices.isEmpty())return args("op","pass");
            if(skill==Skill.EASY){
                List<Choice> moves=choices.stream().filter(c->!c.action.get("op").equals("pass")).toList();
                if(moves.isEmpty())return choices.get(0).action;
                return moves.get(random.nextInt(moves.size())).action;
            }
            double best=-1e9;Map<String,String> answer=choices.get(0).action;int width=Math.min(choices.size(),skill.width);
            for(int i=0;i<width;i++){
                Choice c=choices.get(i);double value;
                if(skill==Skill.NORMAL){
                    value=c.order;
                    if(c.action.get("op").equals("move")){
                        Piece moved=c.after.piece(num(c.action,"id"));double risk=0;
                        if(moved!=null)for(Piece enemy:c.after.pieces)if(enemy.color!=g.turn&&c.after.moves(enemy).contains(moved.pos()))risk=Math.max(risk,value(moved)*.7);
                        value-=risk;
                    }
                    value+=random.nextDouble()*12;
                }else value=search(c.after,g.turn,skill.depth-1)+random.nextDouble()*.1;
                // Zero-turn preparation must improve the position rather than loop forever.
                if(c.after.ply==g.ply&&evaluate(c.after,g.turn)<=evaluate(g,g.turn)+1)value-=30;
                if(value>best){best=value;answer=c.action;}
                if(System.nanoTime()>until&&skill!=Skill.NORMAL)break;
            }
            return answer;
        }
    }
    record Reward(String id,String title,String text) {}
    static class Campaign {
        final long seed;final Random rng;int floor=1;boolean elite;String phase="battle",route="skirmish";
        final Set<String> relics=new LinkedHashSet<>();List<Reward> rewards=new ArrayList<>();
        Campaign(long seed){this.seed=seed;rng=new Random(seed);}
        Game first(){
            Game g=new Game(seed);g.pieces.clear();g.tiles.clear();g.players[0].money=150;
            for(int type:new int[]{5,1,3,0,0})g.add(type,0,0,0);
            return encounter(g,"skirmish");
        }
        Game encounter(Game old,String path){
            route=path;elite=path.equals("elite")||floor%3==0;
            Game g=new Game(rng.nextLong());g.pieces.clear();g.tiles.clear();g.campaignBattle=true;g.shopUnlocked=true;g.cardsUnlocked=true;
            g.players[0]=Bot.copy(old).players[0];g.players[0].hand.clear();g.graves=new ArrayList<>(old.graves);g.bountyBonus=relics.contains("hunter")?25:0;
            List<Piece> survivors=old.pieces.stream().filter(p->p.color==0).toList();int slot=0;
            for(Piece original:survivors){
                if(slot>=32)break;
                Piece p;
                try{p=(Piece)original.clone();}catch(Exception e){throw new AssertionError(e);}
                p.id=g.nextId++;p.x=slot%8;p.y=7-slot/8;p.sx=p.x;p.sy=p.y;p.moved=false;p.frozen=p.armor=p.rat=p.vest=p.blanket=p.fogTurns=0;p.hp=4;
                g.pieces.add(p);slot++;
            }
            int count=3+floor+(elite?2:0);
            List<Integer> enemyFiles=new ArrayList<>(List.of(0,1,2,3,4,5,6,7));Collections.shuffle(enemyFiles,rng);
            for(int i=0;i<count;i++){
                int type=i==0?5:i==1&&floor%3==0?4:i%4==0?3:1+rng.nextInt(Math.min(3,1+floor/2));
                Piece p=g.add(type,1,enemyFiles.get(i%8),i/8);
                if(elite&&i==0){p.shield=true;p.magic=true;}
                if(floor>=4&&i==2){p.type=3;p.upgrade="Golem";}
            }
            if(relics.contains("aegis"))g.pieces.stream().filter(p->p.color==0).limit(2).forEach(p->p.shield=true);
            if(relics.contains("purse"))g.players[0].money+=60;
            if(path.equals("supply")){g.players[0].money+=40;g.players[0].items.add("shield");}
            for(int i=0;i<6;i++){Pos p=new Pos(rng.nextInt(8),2+rng.nextInt(3));if(g.empty(p.x,p.y))g.tiles.put(p,"mystery");}
            g.reveals=2;g.restock();g.draw(0,relics.contains("charm")?3:2,false);g.draw(1,2,false);
            phase="battle";g.note("THE SHATTERED CROWN · battle "+floor+"/6 · "+(floor%3==0?"BOSS":elite?"ELITE":path.toUpperCase(Locale.ROOT))+".");return g;
        }
        void observe(Game g){
            if(!phase.equals("battle")||g.winner==-1)return;
            if(g.winner!=0){phase="defeat";g.note("The expedition falls. Start a new run to try another seed.");return;}
            g.players[0].money+=elite?180:100;
            if(floor==6){phase="victory";g.note("THE SHATTERED CROWN IS YOURS. Six battles survived.");return;}
            phase="reward";List<Reward> pool=new ArrayList<>();
            int troops=(int)g.pieces.stream().filter(p->p.color==0).count();
            if(troops<30){pool.add(new Reward("knight","Recruit a knight","A new knight joins your surviving army."));pool.add(new Reward("bishop","Recruit a bishop","A new bishop joins your surviving army."));pool.add(new Reward("rook","Recruit a rook","A new rook joins your surviving army."));}
            pool.add(new Reward("gold","War chest","Gain $180 to spend in future battles."));
            pool.add(new Reward("supplies","Protective supplies","Gain a Shield and a Magic Shield."));
            if(!relics.contains("aegis"))pool.add(new Reward("aegis","Aegis Banner","Permanent run relic: two survivors start every battle shielded."));
            if(!relics.contains("purse"))pool.add(new Reward("purse","Bottomless Purse","Permanent run relic: gain $60 at each battle start."));
            if(!relics.contains("charm"))pool.add(new Reward("charm","Scholar's Charm","Permanent run relic: begin each battle with 3 cards."));
            if(!relics.contains("hunter"))pool.add(new Reward("hunter","Hunter's Seal","Permanent run relic: friendly captures earn $25 extra."));
            for(Piece p:g.pieces)if(p.color==0&&PATHS[p.type].length>0&&p.upgrade.isEmpty()&&p.fusion.isEmpty()){String path=PATHS[p.type][rng.nextInt(2)];pool.add(new Reward("forge:"+p.id+":"+path,"Royal forge: "+path,"Upgrade this survivor for free."));break;}
            if(troops<30&&g.graves.stream().anyMatch(v->v.color==0))pool.add(new Reward("revive","Second chance","Restore your most recently fallen unit as a base piece."));
            Collections.shuffle(pool,rng);rewards=new ArrayList<>(pool.subList(0,3));g.note("Choose one of three rewards, then choose your next route.");
        }
        void reward(Game g,String id){
            require(phase.equals("reward")&&rewards.stream().anyMatch(r->r.id.equals(id)),"Choose one of the offered rewards.");
            if(List.of("aegis","purse","charm","hunter").contains(id))relics.add(id);
            else if(id.equals("gold"))g.players[0].money+=180;
            else if(id.equals("supplies")){g.players[0].items.add("shield");g.players[0].items.add("magic");}
            else if(id.startsWith("forge:")){String[] p=id.split(":",3);Piece piece=g.piece(Integer.parseInt(p[1]));require(piece!=null,"That survivor is unavailable.");piece.upgrade=p[2];}
            else {
                int type=id.equals("knight")?1:id.equals("bishop")?2:3;
                if(id.equals("revive"))for(int i=g.graves.size()-1;i>=0;i--)if(g.graves.get(i).color==0){type=g.graves.remove(i).type;break;}
                boolean added=false;for(int y=7;y>=0&&!added;y--)for(int x=0;x<8&&!added;x++)if(g.empty(x,y)){g.add(type,0,x,y);added=true;}
                require(added,"Your army is full.");
            }
            phase="route";rewards.clear();g.note("Reward claimed. Choose the next route.");
        }
        Game route(Game g,String id){
            require(phase.equals("route"),"Claim a reward first.");
            boolean boss=(floor+1)%3==0;
            require(boss?id.equals("boss"):List.of("supply","elite").contains(id),"Choose an available route.");
            floor++;return encounter(g,id);
        }
        Map<String,Object> state(){
            List<Object> offered=new ArrayList<>();for(Reward r:rewards)offered.add(map("id",r.id,"title",r.title,"text",r.text));
            return map("floor",floor,"total",6,"phase",phase,"seed",Long.toString(seed),"relics",new ArrayList<>(relics),"rewards",offered,"nextBoss",(floor+1)%3==0,"elite",elite);
        }
    }

    static class Session implements AutoCloseable {
        Game g;long revision=0,deadline;final int seconds;final boolean online;
        final Skill skill;final Bot bot;final Campaign campaign;
        ExecutorService botPool;boolean thinking,closed;int preparations;long nextBotAt;
        boolean solo(){return bot!=null;}
        boolean battling(){return campaign==null||campaign.phase.equals("battle");}
        HttpServer server;ExecutorService httpPool;ScheduledExecutorService clock;
        String[] tokens={token(),token()};
        Session(Game game,boolean online,int seconds){this(game,online,seconds,null,false,0);}
        Session(Game game,boolean online,int seconds,Skill skill,boolean rogue,long seed){
            this.skill=skill;this.bot=skill==null?null:new Bot(skill,seed^0xB07);
            campaign=rogue?new Campaign(seed):null;g=rogue?campaign.first():game;
            this.online=online;this.seconds=seconds;
            if(bot!=null)botPool=Executors.newSingleThreadExecutor(r->{Thread t=new Thread(r,"chess-bot");t.setDaemon(true);return t;});
            resetClock();
        }
        void observe(){if(campaign!=null)campaign.observe(g);}
        void queueBot(){
            if(bot==null||thinking||closed||g.turn!=1||g.winner!=-1||!battling()||System.currentTimeMillis()<nextBotAt)return;
            thinking=true;long expected=revision;Game snapshot=Bot.copy(g);boolean prepare=preparations<4;
            botPool.submit(()->{
                Map<String,String> a;
                try{a=bot.choose(snapshot,prepare);}catch(Exception e){a=args("op","pass");}
                synchronized(this){
                    try{
                        if(closed||revision!=expected||g.turn!=1||g.winner!=-1||!battling())return;
                        int before=g.ply;
                        try{g.action(a);}catch(IllegalArgumentException e){if(g.shopOpen)g.closeShop();else g.action(args("op","pass"));}
                        revision++;preparations++;
                        if(before!=g.ply){resetClock();preparations=0;}
                        observe();nextBotAt=System.currentTimeMillis()+350;
                    }finally{thinking=false;}
                }
            });
        }
        void resetClock(){deadline=System.currentTimeMillis()+seconds*1000L;}
        synchronized void action(int role,Map<String,String> a){
            require(!solo()||role==0,"Onyx is controlled by the bot.");
            if(campaign!=null&&List.of("reward","route").contains(a.get("op"))){
                require(role==0&&Long.toString(revision).equals(a.get("revision")),"The run changed. Try again.");
                if(a.get("op").equals("reward"))campaign.reward(g,a.get("choice"));
                else {g=campaign.route(g,a.get("choice"));preparations=0;resetClock();}
                revision++;return;
            }
            require(battling(),"Choose your run reward or route first.");
            require(role==g.turn,"Wait for your turn.");
            require(Long.toString(revision).equals(a.get("revision")),"The board changed. Select your action again.");
            int before=g.ply;g.action(a);revision++;if(before!=g.ply){resetClock();preparations=0;}observe();
        }
        synchronized void tick(){
            if(seconds>0&&g.winner==-1&&battling()&&System.currentTimeMillis()>=deadline){g.note("Time expired.");g.shopOpen=false;g.end();revision++;preparations=0;resetClock();observe();}
            queueBot();
        }
        synchronized Map<String,Object> state(int role){
            List<Object> ps=new ArrayList<>(),ts=new ArrayList<>(),hs=new ArrayList<>(),hand=new ArrayList<>(),inv=new ArrayList<>(),offers=new ArrayList<>(),fallen=new ArrayList<>();
            for(Piece p:g.pieces){
                boolean hidden=p.blanket>g.ply&&p.color!=role;
                List<Object> legal=new ArrayList<>();if(p.color==role&&role==g.turn&&!g.shopOpen)for(Pos m:g.moves(p))legal.add(List.of(m.x,m.y));
                ps.add(map("id",p.id,"type",hidden?-1:p.type,"name",hidden?"Blanketed piece":p.name(),"color",p.color,"x",p.x,"y",p.y,"icon",hidden?"▧":ICONS[p.type],"effects",hidden?"Blanket":effects(g,p),"upgrade",hidden?"":p.upgrade,"fusion",hidden?"":p.fusion,"legal",legal));
            }
            g.tiles.forEach((p,t)->ts.add(map("x",p.x,"y",p.y,"type",t)));
            g.hazards.forEach((p,h)->hs.add(map("x",p.x,"y",p.y,"type",h.type)));
            for(Card c:g.players[role].hand){Def d=def(CARDS,c.id);hand.add(map("id",d.id,"name",d.name,"target",d.target,"text",d.text+(d.id.equals("collector")?" Worth $"+10*((g.ply-c.born)/2)+".":"")));}
            for(String id:g.players[role].items){Def d=def(ITEMS,id);inv.add(map("id",id,"name",d.name,"target",d.target,"text",d.text));}
            if(g.shopUnlocked)for(String id:g.stock){Def d=def(ITEMS,id);offers.add(map("id",id,"name",d.name,"cost",d.cost,"text",d.text));}
            for(int i=0;i<g.graves.size();i++){Grave v=g.graves.get(i);if(v.color==role)fallen.add(map("index",i,"name",TYPES[v.type],"cost",(VALUES[v.type]+1)/2));}
            int remain=seconds==0?0:(int)Math.max(0,(deadline-System.currentTimeMillis()+999)/1000);
            return map("revision",revision,"role",role,"turn",g.turn,"round",g.ply/2+1,"ply",g.ply,"size",g.size,"winner",g.winner,"pieces",ps,"tiles",ts,"hazards",hs,"fog",g.fog,"shop",g.shopUnlocked,"shopOpen",g.shopOpen&&role==g.turn,"shopFree",g.shopFree,"cards",g.cardsUnlocked,"hand",hand,"items",inv,"stock",offers,"money",List.of(g.players[0].money,g.players[1].money),"handCount",List.of(g.players[0].hand.size(),g.players[1].hand.size()),"limit",g.players[role].limit,"graves",fallen,"log",List.copyOf(g.log),"seconds",seconds,"remaining",remain,"shots",g.shots,"shotsId",g.shotsId,"mode",campaign!=null?"roguelike":solo()?"solo":"multiplayer","difficulty",skill==null?"":skill.name().toLowerCase(Locale.ROOT),"thinking",thinking,"run",campaign==null?null:campaign.state());
        }
        void start(String bind,int port)throws IOException{
            server=HttpServer.create(new InetSocketAddress(bind,port),16);
            httpPool=Executors.newFixedThreadPool(4);server.setExecutor(httpPool);
            server.createContext("/",this::handle);server.start();
            clock=Executors.newSingleThreadScheduledExecutor();clock.scheduleAtFixedRate(this::tick,250,250,TimeUnit.MILLISECONDS);
        }
        int port(){return server.getAddress().getPort();}
        void handle(HttpExchange ex)throws IOException{
            try{
                String path=ex.getRequestURI().getPath(),method=ex.getRequestMethod();
                if(path.equals("/")&&method.equals("GET")){send(ex,200,"text/html",PAGE);return;}
                if(!path.equals("/state")&&!path.equals("/action")){send(ex,404,"text/plain","Not found");return;}
                String provided=ex.getRequestHeaders().getFirst("X-Chess-Token");int role=Objects.equals(tokens[0],provided)?0:Objects.equals(tokens[1],provided)?1:-1;
                if(solo()&&role==1){send(ex,403,"application/json",json(map("error","Onyx is controlled by the bot.")));return;}
                if(role<0){send(ex,401,"application/json",json(map("error","Open the complete player invite link from the host.")));return;}
                if(path.equals("/state")&&method.equals("GET")){send(ex,200,"application/json",json(state(role)));return;}
                if(!path.equals("/action")||!method.equals("POST")){send(ex,405,"application/json",json(map("error","Method not allowed.")));return;}
                byte[] body=ex.getRequestBody().readNBytes(4097);require(body.length<=4096,"Request too large.");
                Map<String,String> fields=parseForm(new String(body,StandardCharsets.UTF_8));
                synchronized(this){action(role,fields);send(ex,200,"application/json",json(state(role)));}
            }catch(IllegalArgumentException e){send(ex,409,"application/json",json(map("error",e.getMessage())));}
            catch(Exception e){send(ex,500,"application/json",json(map("error","Server error. Please retry.")));e.printStackTrace();}
            finally{ex.close();}
        }
        public synchronized void close(){closed=true;if(botPool!=null)botPool.shutdownNow();if(server!=null)server.stop(0);if(httpPool!=null)httpPool.shutdownNow();if(clock!=null)clock.shutdownNow();}
    }
    static String token(){byte[] b=new byte[24];new SecureRandom().nextBytes(b);return Base64.getUrlEncoder().withoutPadding().encodeToString(b);}
    static Map<String,String> parseForm(String s){
        Map<String,String> m=new LinkedHashMap<>();if(s.isEmpty())return m;
        for(String field:s.split("&")){String[] p=field.split("=",2);m.put(URLDecoder.decode(p[0],StandardCharsets.UTF_8),URLDecoder.decode(p.length>1?p[1]:"",StandardCharsets.UTF_8));}return m;
    }
    static void send(HttpExchange ex,int status,String type,String value)throws IOException{
        byte[] bytes=value.getBytes(StandardCharsets.UTF_8);
        ex.getResponseHeaders().set("Content-Type",type+"; charset=utf-8");
        ex.getResponseHeaders().set("Cache-Control","no-store");
        ex.getResponseHeaders().set("X-Content-Type-Options","nosniff");
        ex.getResponseHeaders().set("Referrer-Policy","no-referrer");
        ex.getResponseHeaders().set("Content-Security-Policy","default-src 'self'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'; img-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'");
        ex.sendResponseHeaders(status,bytes.length);ex.getResponseBody().write(bytes);
    }
    // Desktop and embedded browser interface follow below.

    static final Color BG=new Color(17,24,20),PANEL=new Color(29,39,31),GOLD=new Color(221,194,133),TEXT=new Color(238,235,220),MUTED=new Color(159,176,153);
    static class Desktop {
        Session s;JFrame frame=new JFrame("Chess II — AI version with younger me's dreams");
        BoardCanvas board=new BoardCanvas();JPanel sidebar=new JPanel(),hand=new JPanel();
        JLabel status=new JLabel(),message=new JLabel("Select a piece, then a highlighted square.");
        int selected=-1,index=-1,graveIndex=-1;String mode="",ability="";long displayed=-1;
        boolean flip;javax.swing.Timer refresh;
        Desktop(Session session){
            s=session;frame.setDefaultCloseOperation(WindowConstants.DISPOSE_ON_CLOSE);
            frame.setSize(1250,920);frame.setMinimumSize(new Dimension(760,640));frame.getContentPane().setBackground(BG);
            JPanel root=new JPanel(new BorderLayout(16,12));root.setBorder(new EmptyBorder(18,20,18,20));root.setBackground(BG);frame.setContentPane(root);
            JPanel top=new JPanel(new BorderLayout());top.setOpaque(false);
            JLabel title=new JLabel("<html><span style='font-size:25px'>CHESS II</span><br><span style='font-size:11px'>AI version with younger me's dreams</span></html>");title.setForeground(GOLD);
            top.add(title,BorderLayout.WEST);status.setForeground(TEXT);top.add(status,BorderLayout.CENTER);
            JPanel controls=new JPanel(new FlowLayout(FlowLayout.RIGHT));controls.setOpaque(false);
            controls.add(button("Rules",()->JOptionPane.showMessageDialog(frame,RULES,"How to play",JOptionPane.INFORMATION_MESSAGE)));
            controls.add(button("Flip board",()->{flip=!flip;board.repaint();}));
            controls.add(button("Cancel target",()->{mode="";message.setText("Targeting canceled.");board.repaint();}));
            top.add(controls,BorderLayout.EAST);root.add(top,BorderLayout.NORTH);
            JScrollPane field=new JScrollPane(board);field.getViewport().setBackground(BG);field.setBorder(BorderFactory.createLineBorder(new Color(70,87,64),6));root.add(field,BorderLayout.CENTER);
            sidebar.setBackground(PANEL);sidebar.setLayout(new BoxLayout(sidebar,BoxLayout.Y_AXIS));sidebar.setBorder(new EmptyBorder(14,14,14,14));
            JScrollPane sideScroll=new JScrollPane(sidebar);sideScroll.setPreferredSize(new Dimension(285,500));sideScroll.setBorder(null);root.add(sideScroll,BorderLayout.EAST);
            JPanel bottom=new JPanel(new BorderLayout(0,10));bottom.setOpaque(false);message.setForeground(GOLD);bottom.add(message,BorderLayout.NORTH);
            hand.setBackground(BG);hand.setLayout(new FlowLayout(FlowLayout.LEFT,8,6));JScrollPane cards=new JScrollPane(hand);cards.setPreferredSize(new Dimension(800,135));cards.setBorder(null);bottom.add(cards,BorderLayout.CENTER);root.add(bottom,BorderLayout.SOUTH);
            refresh=new javax.swing.Timer(200,e->{s.tick();synchronized(s){if(displayed!=s.revision)render();else updateStatus();}});
            frame.addWindowListener(new WindowAdapter(){public void windowClosed(WindowEvent e){refresh.stop();s.close();}});
            synchronized(s){render();}frame.setLocationRelativeTo(null);frame.setVisible(true);refresh.start();
        }
        int role(){return s.online||s.solo()?0:s.g.turn;}
        JButton button(String text,Runnable fn){
            JButton b=new JButton(text);b.setBackground(new Color(44,60,43));b.setForeground(TEXT);b.setFocusPainted(false);b.setMargin(new Insets(9,11,9,11));b.addActionListener(e->fn.run());return b;
        }
        void label(String text,Color color){JLabel l=new JLabel("<html>"+html(text)+"</html>");l.setForeground(color);l.setBorder(new EmptyBorder(5,0,5,0));sidebar.add(l);}
        static String html(String s){return s.replace("&","&amp;").replace("<","&lt;").replace(">","&gt;").replace("\n","<br>");}
        void run(Map<String,String> a){
            synchronized(s){try{a.put("revision",Long.toString(displayed));s.action(role(),a);mode="";selected=-1;message.setText(s.g.log.get(0));render();}catch(IllegalArgumentException e){message.setText(e.getMessage());}}
        }
        void updateStatus(){
            Game g=s.g;String t=g.winner==-1?side(g.turn)+" to move":g.winner==2?"Draw":side(g.winner)+" wins";
            status.setText("<html>&nbsp;&nbsp; ROUND "+(g.ply/2+1)+" · "+t+"<br>&nbsp;&nbsp; Ivory $"+g.players[0].money+" · Onyx $"+g.players[1].money+(s.seconds>0?" · "+Math.max(0,(s.deadline-System.currentTimeMillis()+999)/1000)+"s":"")+"<br>&nbsp;&nbsp; "+(s.solo()?(s.campaign!=null?"THE SHATTERED CROWN · ":"SOLO · ")+s.skill.name()+(s.thinking?" · bot thinking…":""):s.online?"HOSTING · you are Ivory":"LOCAL TWO-PLAYER")+"</html>");
        }
        void arm(String kind,int i,Def d){
            if(d.target.equals("none")){run(args("op",kind,"index",""+i));return;}
            mode=kind;index=i;message.setText(d.name+" — "+d.text+" Choose "+d.target+".");board.repaint();
        }
        void ability(String name){
            synchronized(s){
                Piece p=s.g.piece(selected);if(p==null)return;
                if(name.equals("revive")){
                    List<Integer> entries=new ArrayList<>();List<String> options=new ArrayList<>();
                    for(int i=0;i<s.g.graves.size();i++){Grave v=s.g.graves.get(i);if(v.color==role()){entries.add(i);options.add(TYPES[v.type]+" · $"+((VALUES[v.type]+1)/2)+" · #"+i);}}
                    if(options.isEmpty()){message.setText("No fallen allies to revive.");return;}
                    Object chosen=JOptionPane.showInputDialog(frame,"Choose a fallen ally","Revive",JOptionPane.PLAIN_MESSAGE,null,options.toArray(),options.get(0));
                    if(chosen==null)return;graveIndex=entries.get(options.indexOf(chosen.toString()));
                }
                mode="ability";ability=name;message.setText(name+" — select a target square.");
            }
        }
        void render(){
            Game g=s.g;if(displayed!=s.revision){mode="";selected=-1;}displayed=s.revision;updateStatus();sidebar.removeAll();hand.removeAll();
            int role=role();boolean can=role==g.turn&&g.winner==-1;Piece p=g.piece(selected);
            if(s.campaign!=null){
                Campaign c=s.campaign;label("THE SHATTERED CROWN · "+c.floor+"/6",GOLD);
                label("Seed "+c.seed+"\nRun relics: "+(c.relics.isEmpty()?"none":String.join(", ",c.relics)),MUTED);
                if(c.phase.equals("reward")){label("CHOOSE ONE REWARD",GOLD);for(Reward r:c.rewards){JButton b=button(r.title,()->run(args("op","reward","choice",r.id)));b.setToolTipText(r.text);sidebar.add(b);label(r.text,MUTED);}}
                if(c.phase.equals("route")){
                    label("CHOOSE YOUR ROUTE",GOLD);
                    if((c.floor+1)%3==0)sidebar.add(button("Face the boss →",()->run(args("op","route","choice","boss"))));
                    else {sidebar.add(button("Supply route · $40 + Shield",()->run(args("op","route","choice","supply"))));sidebar.add(button("Elite route · stronger enemy, +$180",()->run(args("op","route","choice","elite"))));}
                }
                if(c.phase.equals("victory"))label("RUN WON · Six battles survived!",GOLD);
                if(c.phase.equals("defeat"))label("RUN LOST · Your army has fallen.",GOLD);
                if(!c.phase.equals("battle")){board.repaint();sidebar.revalidate();sidebar.repaint();hand.revalidate();hand.repaint();return;}
            }
            label(g.size==8?"THE OPENING FIELD":"THE EXPANSE",GOLD);
            label("Kings can die. The battle continues.\nEliminate the enemy army to win.",MUTED);
            if(g.winner!=-1)label(g.winner==2?"A spectacular draw.":side(g.winner)+" reigns victorious.",GOLD);
            JButton end=button("End turn →",()->run(args("op","pass")));end.setEnabled(can&&!g.shopOpen);sidebar.add(end);
            if(g.shopOpen&&can){
                label("THE BAZAAR · "+(g.shopFree?"Free browsing":"Visiting costs your turn"),GOLD);
                for(String id:g.stock){Def d=def(ITEMS,id);JButton buy=button(d.name+" · $"+d.cost,()->run(args("op","buy","item",id)));buy.setToolTipText(d.text);buy.setEnabled(g.players[role].money>=d.cost);sidebar.add(buy);}
                sidebar.add(button("Refresh · $25",()->run(args("op","reroll"))));
                sidebar.add(button("Upgrade selected piece · $250",()->{
                    synchronized(s){Piece q=s.g.piece(selected);if(q==null||PATHS[q.type].length==0){message.setText("Select a knight, bishop, or rook on the board.");return;}
                    Object path=JOptionPane.showInputDialog(frame,"Choose an upgrade","Upgrade",JOptionPane.PLAIN_MESSAGE,null,PATHS[q.type],PATHS[q.type][0]);
                    if(path!=null)run(args("op","upgrade","id",""+q.id,"path",path.toString()));}
                }));
                sidebar.add(button("Fuse two paths · $500",()->{
                    String[] names={"Knight → Sky Strider","Bishop → Archmage","Rook → Iron Warden"};
                    Object choice=JOptionPane.showInputDialog(frame,"Choose fusion; then click an empty back-rank square","Alignation",JOptionPane.PLAIN_MESSAGE,null,names,names[0]);
                    if(choice!=null){index=Arrays.asList(names).indexOf(choice.toString())+1;mode="fuse";message.setText("Select an empty square on your back rank.");}
                }));
                sidebar.add(button("Leave Bazaar",()->run(args("op","leave"))));
            }else{
                JButton shop=button(g.shopUnlocked?"Enter the Bazaar":"Bazaar undiscovered",()->run(args("op","shop")));shop.setEnabled(can&&g.shopUnlocked);sidebar.add(shop);
            }
            if(p!=null){
                label(p.name()+" · "+square(p.x,p.y),GOLD);label(effects(g,p),MUTED);
                if(can&&p.color==role&&!g.shopOpen){
                    if(p.upgrade.equals("M1 Abrams")||p.fusion.equals("Iron Warden")||p.fusion.equals("Archmage"))sidebar.add(button("Aim cannon / spell",()->ability("shoot")));
                    if(p.fusion.equals("Archmage")){sidebar.add(button("Summon pawn",()->ability("summon")));sidebar.add(button("Warp > 5 squares",()->ability("teleport")));}
                    if(p.upgrade.equals("Divine Cleric"))sidebar.add(button("Revive a fallen ally",()->ability("revive")));
                }
            }
            label("RELICS",GOLD);
            for(int i=0;i<g.players[role].items.size();i++){int idx=i;Def d=def(ITEMS,g.players[role].items.get(i));JButton b=button(d.name,()->arm("item",idx,d));b.setToolTipText(d.text);b.setEnabled(can&&!g.shopOpen);sidebar.add(b);}
            if(g.players[role].items.isEmpty())label("Find or buy your first relic.",MUTED);
            label("THE CHRONICLE",GOLD);for(String entry:g.log.subList(0,Math.min(8,g.log.size())))label(entry,MUTED);
            for(int i=0;i<g.players[role].hand.size();i++){
                int idx=i;Card c=g.players[role].hand.get(i);Def d=def(CARDS,c.id);
                JButton b=button("<html><b>"+html(d.name)+"</b><br><div style='width:145px'>"+html(d.text)+"</div></html>",()->arm("card",idx,d));b.setPreferredSize(new Dimension(180,95));b.setEnabled(can&&!g.shopOpen);hand.add(b);
            }
            if(g.players[role].hand.isEmpty()){JLabel empty=new JLabel(g.cardsUnlocked?"Your hand is empty. Draw next turn.":"The second mystery tile awakens the card game.");empty.setForeground(MUTED);hand.add(empty);}
            board.setPreferredSize(new Dimension(g.size==20?900:640,g.size==20?900:640));board.revalidate();board.repaint();sidebar.revalidate();sidebar.repaint();hand.revalidate();hand.repaint();
        }
        class BoardCanvas extends JPanel {
            BoardCanvas(){setBackground(BG);addMouseListener(new MouseAdapter(){public void mouseClicked(MouseEvent e){click(e.getX(),e.getY());}});}
            void click(int mx,int my){
                synchronized(s){
                    Game g=s.g;int cell=Math.min(getWidth(),getHeight())/g.size;if(cell<1)return;int x=mx/cell,y=my/cell;if(!g.inside(x,y))return;if(flip){x=g.size-1-x;y=g.size-1-y;}
                    if(role()!=g.turn){message.setText("Waiting for your friend.");return;}
                    if(!mode.isEmpty()){
                        Map<String,String> a=args("op",mode,"x",""+x,"y",""+y);
                        if(mode.equals("ability")){a.put("id",""+selected);a.put("ability",ability);a.put("grave",""+graveIndex);}
                        else if(mode.equals("fuse"))a.put("type",""+index);else a.put("index",""+index);
                        run(a);return;
                    }
                    Piece p=g.piece(selected);
                    if(!g.shopOpen&&p!=null&&p.color==role()&&g.moves(p).contains(new Pos(x,y))){run(args("op","move","id",""+p.id,"x",""+x,"y",""+y));return;}
                    Piece q=g.at(x,y);selected=q==null?-1:q.id;render();
                }
            }
            protected void paintComponent(Graphics graphics){
                super.paintComponent(graphics);Graphics2D d=(Graphics2D)graphics.create();d.setRenderingHint(RenderingHints.KEY_ANTIALIASING,RenderingHints.VALUE_ANTIALIAS_ON);
                synchronized(s){
                    Game g=s.g;int cell=Math.min(getWidth(),getHeight())/g.size;Piece chosen=g.piece(selected);
                    Set<Pos> legal=chosen!=null&&chosen.color==role()&&!g.shopOpen&&mode.isEmpty()?g.moves(chosen):Set.of();
                    for(int y=0;y<g.size;y++)for(int x=0;x<g.size;x++){
                        int px=(flip?g.size-1-x:x)*cell,py=(flip?g.size-1-y:y)*cell;Pos pos=new Pos(x,y);
                        Color c=(x+y)%2==0?new Color(161,173,140):new Color(65,85,73);
                        Hazard h=g.hazards.get(pos);if(h!=null)c=h.type.equals("fire")?new Color(155,90,53):new Color(113,131,65);
                        d.setColor(c);d.fillRect(px,py,cell,cell);
                        if(g.fog&&(y==g.size/2||y==g.size/2-1)){d.setColor(new Color(220,233,220,80));d.fillRect(px,py,cell,cell);}
                        String tile=g.tiles.get(pos);
                        if(tile!=null){d.setColor(GOLD);d.setFont(new Font("Dialog",Font.BOLD,Math.max(15,cell/3)));d.drawString(tile.equals("mystery")?"✦":"●",px+cell/3,py+cell/2);}
                        Piece p=g.at(x,y);
                        if(p!=null){
                            String glyph=p.blanket>g.ply&&p.color!=role()?"▧":ICONS[p.type];
                            d.setFont(new Font("Dialog",Font.PLAIN,Math.max(18,(int)(cell*.78))));FontMetrics fm=d.getFontMetrics();int gx=px+(cell-fm.stringWidth(glyph))/2,gy=py+(cell-fm.getHeight())/2+fm.getAscent();
                            d.setColor(p.color==0?new Color(63,66,53):new Color(201,210,180));d.drawString(glyph,gx+1,gy+1);
                            d.setColor(p.color==0?new Color(248,239,208):new Color(18,34,27));d.drawString(glyph,gx,gy);
                            if(p.frozen>g.ply){d.setColor(new Color(125,220,244));d.drawRect(px+4,py+4,cell-8,cell-8);}
                            if(p.shield||!p.upgrade.isEmpty()||!p.fusion.isEmpty()){d.setFont(new Font("Dialog",Font.BOLD,Math.max(9,cell/5)));d.setColor(GOLD);d.drawString(!p.fusion.isEmpty()?"✶":!p.upgrade.isEmpty()?"↑":"◇",px+cell-16,py+cell-5);}
                            if(p.id==selected){d.setColor(GOLD);d.setStroke(new BasicStroke(3));d.drawRect(px+2,py+2,cell-4,cell-4);}
                        }
                        if(legal.contains(pos)){d.setColor(new Color(32,57,33,180));if(p==null)d.fillOval(px+cell*2/5,py+cell*2/5,cell/5,cell/5);else{d.setColor(new Color(173,74,48));d.setStroke(new BasicStroke(3));d.drawOval(px+3,py+3,cell-6,cell-6);}}
                        d.setFont(new Font("Dialog",Font.PLAIN,Math.max(8,cell/8)));d.setColor((x+y)%2==0?new Color(42,61,42):new Color(203,216,180));d.drawString(square(x,y),px+3,py+cell-3);
                    }
                }d.dispose();
            }
        }
    }
    static final String RULES = """
        CHESS II — local two-player or self-hosted multiplayer
        • Start with $200. Capture pieces for gold. Kings pay $500; the game continues.
        • Eliminate the entire enemy army to win. No check or checkmate.
        • First mystery tile opens the Bazaar; second enables cards.
        • Play cards and relics before moving. Moving ends your turn.
        • Shop visits cost a turn, even without buying. Every fifth round offers
          one free browsing visit; purchases still cost your turn.
        • Pawns promote to queens. No ordinary castling or en passant.
        • Shields consume the attack. A frozen piece cannot move.
        • Round 20 expands the board to 20×20. Scroll to explore.
        • Upgrade both paths of a piece type, then fuse them for $500.
        • Range uses square distance (including diagonals), unless specified.
        • The optional timer keeps running during dialogs and shop visits.
        • Restart the program for a new match. Closing the host ends the session.
        This alpha implements a first set of the ideas, not the entire brainstorm.
        """;

    static final String PAGE = """
<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Chess II · Younger Me's Dreams</title>
<style>
:root{color-scheme:dark;--bg:#101812;--panel:#1c281f;--gold:#d8bd7f;--text:#eee9d7;--muted:#9aad96;--line:#354731;--lime:#bfd995}
*{box-sizing:border-box}body{margin:0;background:radial-gradient(ellipse at top,#2b412855,transparent 65%),var(--bg);color:var(--text);font:14px Georgia,serif}
header{border-bottom:1px solid var(--line);padding:20px 4%;display:flex;justify-content:space-between;align-items:center;gap:16px}
.logo{font-size:28px;letter-spacing:3px}.logo b{color:var(--gold);font-weight:normal}header small{display:block;font-size:11px;letter-spacing:0;color:var(--muted);margin-top:6px;font-style:italic}
button,select{font:12px Arial,sans-serif;border:1px solid var(--line);border-radius:5px;background:#293a27;color:var(--text);padding:10px 13px;cursor:pointer}button:hover:not(:disabled){border-color:var(--gold)}button:disabled{opacity:.4;cursor:not-allowed}button:focus-visible{outline:3px solid var(--gold);outline-offset:2px}
main{max-width:1380px;margin:auto;padding:30px 4%}.intro{display:flex;justify-content:space-between;align-items:end;margin-bottom:27px}h1{font-weight:400;font-size:36px;margin:6px 0}h1 em{color:var(--lime)}.eyebrow{font:10px Arial;letter-spacing:2px;color:var(--gold)}.muted{font:12px/1.6 Arial;color:var(--muted)}
.layout{display:grid;grid-template-columns:195px minmax(280px,1fr) 245px;gap:22px;align-items:start}.panel{border:1px solid var(--line);border-radius:7px;background:var(--panel);padding:17px;margin-bottom:15px}.panel h2{font-size:23px;font-weight:400;margin:10px 0}
#turn{font-size:25px}.money{display:flex;justify-content:space-between;border-top:1px solid var(--line);padding:12px 0;font:12px Arial}.money strong{font:22px Georgia;color:var(--gold)}.primary{background:var(--lime);color:#172617;font-weight:bold;width:100%;margin:8px 0}.gold{background:var(--gold);color:#292b18;width:100%;font-weight:bold}
#notice{border-left:2px solid var(--lime);background:#263b25;padding:12px;font:12px/1.5 Arial;color:var(--lime);margin:16px 0;min-height:42px}.error{border-color:#ed9e7c!important;color:#edb698!important}
.board-wrap{overflow:auto;max-height:780px;border:6px solid #2c3b2b;outline:1px solid #586649;border-radius:3px}#board{display:grid;grid-template-columns:repeat(var(--n),1fr);aspect-ratio:1;min-width:270px}
#board.zoom{min-width:1000px}.square{aspect-ratio:1;border:0;border-radius:0;position:relative;background:#a2ae8c;padding:0;display:flex;align-items:center;justify-content:center;isolation:isolate;min-width:0;color:#15291d}
.square.dark{background:#425b4b}.square:hover:not(:disabled){background:#b1ba89}.square.sel{box-shadow:inset 0 0 0 3px #edd487}.glyph{font:clamp(24px,4.8vw,66px) Georgia;line-height:1;z-index:2;filter:drop-shadow(0 2px 1px #0004)}.ivory{color:#f4eed3;-webkit-text-stroke:1px #555b47}.onyx{color:#14291e;-webkit-text-stroke:.6px #b4c4a3}
.large .glyph{font-size:clamp(12px,2.1vw,27px)}.large.zoom .glyph{font-size:37px}.square.legal:after{content:'';width:20%;height:20%;background:#263f28a0;border-radius:50%;position:absolute;z-index:3}.square.capture:after{width:87%;height:87%;background:transparent;border:3px solid #b75c3f}
.square .tile{position:absolute;color:#ecd08b;font-size:25px;z-index:0}.square.has .tile{right:1px;top:0;font-size:12px}.large .tile{font-size:13px}.coord{position:absolute;bottom:2px;left:3px;font:8px Arial;color:#33472d}.dark .coord{color:#cedbb8}.large .coord{font-size:6px}
.square.fog:before{content:'';position:absolute;inset:0;background:#e0eae63b;z-index:1}.square.fire{background:#a1633c}.square.gas{background:#778448}.badge{position:absolute;right:3px;bottom:2px;font:10px Arial;color:#ffe2a1;background:#213320;border-radius:3px;padding:2px;z-index:4}.large .badge{font-size:6px;padding:0}
.toolbar,.legend{display:flex;justify-content:space-between;align-items:center;color:var(--muted);font:10px Arial;letter-spacing:1px;margin-bottom:12px}.toolbar button{font-size:10px;padding:7px}.legend{margin:12px 0}
#hand{display:grid;grid-template-columns:repeat(auto-fit,minmax(112px,1fr));gap:8px}.card{text-align:left;min-height:123px;display:flex;flex-direction:column;gap:8px;background:linear-gradient(140deg,#37452b,#202e23);padding:12px}.card b{font:15px Georgia;color:#e7d9b0}.card small{font:10px/1.5 Arial;color:var(--muted)}.armed{border-color:#ffe2a0!important;background:#455133!important}.relic{width:100%;text-align:left;margin:5px 0}.relic small{display:block;font:10px/1.5 Arial;color:var(--muted);margin-top:5px}
#selected{font:12px/1.6 Arial;color:var(--muted)}#selected b{display:block;font:20px Georgia;color:var(--text);margin:10px 0}#selected button{display:block;width:100%;margin:7px 0}.bazaar{background:radial-gradient(ellipse at top right,#6b613144,transparent),var(--panel)}
#log{max-height:260px;overflow:auto}#log p{font:11px/1.5 Arial;color:var(--muted);border-bottom:1px solid var(--line);padding-bottom:10px}.empty{border:1px dashed var(--line);padding:18px;color:var(--muted);font:12px/1.7 Arial;grid-column:1/-1}
dialog{background:#1e2b20;color:var(--text);border:1px solid #68724c;border-radius:8px;padding:28px;width:calc(100% - 30px);max-width:800px}dialog::backdrop{background:#07130ce8;backdrop-filter:blur(3px)}.heading{display:flex;justify-content:space-between;align-items:start;gap:12px}.heading h2{font-weight:400;font-size:28px;margin:5px 0 15px}dialog p{font:13px/1.65 Arial;color:var(--muted)}.shopgrid{display:grid;grid-template-columns:1fr 1fr;gap:12px}.offer{padding:17px;border:1px solid var(--line);border-radius:5px}.offer h3{font-size:20px;font-weight:400;color:var(--gold)}.offer button{display:block;width:100%;margin:8px 0}.tabs{display:flex;gap:8px;margin:15px 0}.tabs .active{border-color:var(--gold);color:var(--gold)}#runPanel button{display:block;width:100%;margin:8px 0}#network{font:11px Arial;color:var(--muted)}footer{color:var(--muted);font:10px Arial;border-top:1px solid var(--line);padding:22px 0;margin-top:25px}
@media(max-width:1050px){.layout{grid-template-columns:165px minmax(280px,1fr)}.right{grid-column:1/-1;display:grid;grid-template-columns:1fr 1fr;gap:15px}.right .panel:last-child{grid-column:1/-1}.glyph{font-size:clamp(28px,6vw,64px)}}
@media(max-width:640px){header{padding:14px}.logo{font-size:22px}main{padding:20px 12px}.intro{margin-bottom:20px}h1{font-size:30px}.intro .muted{display:none}.layout{display:flex;flex-direction:column;gap:12px}.left{display:grid;grid-template-columns:1fr 1fr;gap:10px;width:100%}.left .panel{margin:0}.left .selection{grid-column:1/-1}.center,.right{width:100%}.right{gap:10px}.glyph{font-size:clamp(26px,9vw,53px)}.large .glyph{font-size:clamp(10px,3.3vw,19px)}.shopgrid{grid-template-columns:1fr}#hand{grid-template-columns:repeat(auto-fit,minmax(95px,1fr))}.panel{padding:13px}.badge{font-size:8px}.board-wrap{border-width:4px}}
</style>
<header><div class="logo">♞ CHESS <b>II</b><small>AI version with younger me's dreams</small></div><div><span id="network">Connecting…</span> <button id="rulesBtn">How to play</button></div></header>
<main><section class="intro"><div><div class="eyebrow">A VERY UNREASONABLE GAME OF CHESS</div><h1>The crown is optional.<br><em>The chaos isn't.</em></h1></div><span class="muted">Java-powered · privately hosted<br>No subscriptions. No rented server.</span></section>
<div class="layout"><aside class="left"><section id="runPanel" class="panel" hidden></section><section class="panel"><div class="eyebrow" id="round">ROUND 01</div><h2 id="turn">Connecting…</h2><p class="muted" id="you"></p><p class="muted" id="timer"></p><button class="primary" id="pass" disabled>End turn →</button></section><section class="panel"><div id="money"></div><p class="muted" id="world">Discover the mystery tiles.</p></section><section class="panel selection"><div class="eyebrow">ON THE FIELD</div><div id="selected">Select a piece to inspect its powers.</div></section></aside>
<section class="center"><div class="toolbar"><span id="field">THE OPENING FIELD</span><div><button id="cancel">Cancel target</button> <button id="flip">↻ Flip</button> <button id="zoom" hidden>Zoom</button></div></div><div class="board-wrap"><div id="board" role="grid" aria-label="Chess II battlefield"></div></div><div class="legend"><span>✦ MYSTERY TILE</span><span>● AVAILABLE MOVE</span><span id="size">8 × 8</span></div><div id="notice" role="status" aria-live="polite">Open your full invite link from the host.</div><h2 style="font-weight:400">Your hand <small class="muted" id="count"></small></h2><div id="hand"></div></section>
<aside class="right"><section class="panel bazaar"><div class="eyebrow">POWER HAS A PRICE</div><h2>♜ The Bazaar</h2><p class="muted" id="shopHint">The first mystery tile unlocks the shop.</p><button class="gold" id="shopBtn" disabled>Enter Bazaar →</button></section><section class="panel"><div class="eyebrow">RELICS</div><div id="items"></div></section><section class="panel"><div class="eyebrow">THE CHRONICLE</div><div id="log"></div></section></aside></div>
<footer>PLAYABLE ALPHA · one shared game, two private hands · closing the host ends the session</footer></main>
<dialog id="shop"><div class="heading"><div><div class="eyebrow">THE BAZAAR</div><h2>Choose your unfair advantage.</h2></div><button id="leave">Leave</button></div><p id="shopStatus"></p><div class="tabs"><button data-tab="relics">Relics</button><button data-tab="upgrades">Upgrades</button><button data-tab="fusion">Alignations</button></div><div id="shopContent" class="shopgrid"></div></dialog>
<dialog id="rules"><div class="heading"><h2>Forget checkmate.</h2><button id="closeRules">✕</button></div><p>Click a piece, then a highlighted square. Ivory goes first. Moving ends your turn. Capture an entire army to win; kings can die and pay a $500 bounty.</p><p>The first mystery tile unlocks the shop. The second unlocks cards. Play cards and stored relics before moving. Both players start with $200.</p><p>Shop visits use your turn, even without buying. Every fifth round offers one free browsing visit per player; buying always ends the turn. Upgrades cost $250. Combine both distinct paths for $500 to create an Alignation.</p><p>Round 20 expands the board to 20×20. Use Zoom and scroll. Pawns automatically promote to queens. No ordinary castling or en passant. Range includes diagonals unless stated otherwise.</p><p>Your hand is private. Your invite link restores your seat after a refresh. Keep your invite link; only share the other player's link. The host must keep Java running. There is no match persistence after shutdown in this alpha.</p><p>If enabled by the host, the turn timer keeps running during the shop and help dialogs.</p><button class="primary" id="play">Let the chaos begin →</button></dialog>
<script>
'use strict';
const $=id=>document.getElementById(id),token=location.hash.slice(1),side=c=>c===0?'Ivory':'Onyx';
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let state=null,selected=null,armed=null,flipped=false,zoom=false,pending=false,polling=false,connected=false,tab='relics',first=true;
const descriptions={Dragon:'Knight + forward and diagonal-forward rays up to 2 squares.',Unicorn:'Knight jump, then an optional 1-square step from an empty landing square.','M1 Abrams':'Rook movement. Cannon range 1; firing ends your turn.',Golem:'Rook movement up to 3 squares. Immune to direct attacks from farther than 2.',Necromancer:'Bishop. Captures summon 2 pawns near your back rank.','Divine Cleric':'Bishop movement, no captures. Revive a fallen ally within 2 squares for half cost.','Sky Strider':'Queen lines that jump over blockers, plus knight movement.','Iron Warden':'2-square movement. Immune to direct attacks. Takes 4 ranged hits. Range-2 cannon, twice per turn.',Archmage:'Bishop. Range-3 orthogonal spell; summon adjacent pawn; warp farther than 5 squares.'};
function notice(t,error=false){$('notice').textContent=t;$('notice').classList.toggle('error',error)}
function button(text,fn,disabled=false){const b=document.createElement('button');b.textContent=text;b.onclick=fn;b.disabled=disabled;return b}
async function act(a){
 if(!state||pending||!connected)return;pending=true;const sentRevision=state.revision;
 try{const r=await fetch('/action',{method:'POST',headers:{'X-Chess-Token':token,'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({...a,revision:sentRevision})});const v=await r.json();if(!r.ok)throw Error(v.error||'Action failed');state=v;selected=null;armed=null;notice(v.log[0]);render();}
 catch(e){notice(e.message,true);await poll();}finally{pending=false;}
}
async function poll(){
 if(polling)return;polling=true;
 try{const r=await fetch('/state',{headers:{'X-Chess-Token':token},cache:'no-store',signal:AbortSignal.timeout(5000)});const v=await r.json();if(!r.ok)throw Error(v.error||'Cannot connect');connected=true;$('network').textContent='● Connected';
 if(state&&v.revision<state.revision)return;
 if(!state||v.revision!==state.revision){selected=null;armed=null;state=v;render();}else{state.remaining=v.remaining;state.thinking=v.thinking;timer();}
 if(first){first=false;flipped=v.role===1;render();notice('You are '+side(v.role)+'. '+(v.difficulty?'Playing the '+v.difficulty+' bot.':side(v.turn)+' moves first.'));}
 }catch(e){connected=false;$('network').textContent='○ Disconnected · retrying';notice(e.message+' — host must keep Java running.',true);}
 finally{polling=false}
}
function timer(){$('timer').textContent=(state.thinking?'Bot thinking… · ':'')+(state.seconds?state.remaining+' seconds left':'Untimed match')}
function arm(kind,index,d){if(armed&&armed.kind===kind&&armed.index===index){armed=null;render();notice('Targeting canceled.');return}if(d.target==='none'){act({op:kind,index});return}armed={kind,index,id:d.id};selected=null;render();notice(d.name+' · '+d.text+' Choose '+d.target+'.')}
function squareClick(x,y){
 if(!state||state.turn!==state.role||state.winner!==-1)return;
 if(armed){if(armed.kind==='ability')act({op:'ability',id:armed.piece,ability:armed.ability,grave:armed.grave??-1,x,y});else act({op:armed.kind,index:armed.index,x,y});return}
 const p=state.pieces.find(p=>p.id===selected);
 if(p&&p.legal.some(m=>m[0]===x&&m[1]===y)){act({op:'move',id:p.id,x,y});return}
 selected=state.pieces.find(p=>p.x===x&&p.y===y)?.id??null;render();
}
function aim(p,ability){let grave=-1;if(ability==='revive'){if(!state.graves.length){notice('No fallen allies to revive.',true);return}const options=state.graves.map(g=>g.index+': '+g.name+' ($'+g.cost+')').join('\\n');const input=prompt('Choose a fallen ally by number:\\n'+options,String(state.graves[0].index));if(input===null)return;grave=Number(input);if(!state.graves.some(g=>g.index===grave)){notice('Choose one of the listed numbers.',true);return}}
 armed={kind:'ability',piece:p.id,ability,grave};notice(ability+' · choose a target square.');render()
}
function render(){
 const s=state;if(!s)return;const can=s.turn===s.role&&s.winner===-1;
 const panel=$('runPanel');panel.hidden=!s.run;panel.innerHTML='';
 if(s.run){const r=s.run;panel.innerHTML='<div class="eyebrow">THE SHATTERED CROWN</div><h2>Battle '+r.floor+' / 6</h2><p class="muted">Run relics: '+esc(r.relics.join(', ')||'none')+'</p>';
 if(r.phase==='reward'){panel.append(document.createTextNode('Choose one reward'));for(const d of r.rewards){const b=button(d.title,()=>act({op:'reward',choice:d.id}));b.title=d.text;panel.append(b);const p=document.createElement('p');p.className='muted';p.textContent=d.text;panel.append(p)}}
 if(r.phase==='route'){panel.append(document.createTextNode('Choose your next route'));if(r.nextBoss)panel.append(button('Face the boss →',()=>act({op:'route',choice:'boss'})));else{panel.append(button('Supply route · $40 + Shield',()=>act({op:'route',choice:'supply'})));panel.append(button('Elite route · stronger foes, +$180',()=>act({op:'route',choice:'elite'})))}}
 if(['victory','defeat'].includes(r.phase)){const h=document.createElement('h2');h.textContent=r.phase==='victory'?'RUN WON!':'RUN LOST';panel.append(h)}
 }
 $('round').textContent='ROUND '+String(s.round).padStart(2,'0');$('turn').textContent=s.winner===-1?side(s.turn)+' to move':s.winner===2?'A spectacular draw':side(s.winner)+' wins';
 $('you').textContent='You are '+side(s.role)+(s.difficulty?' · '+s.difficulty+' bot':'')+(can?' · your move':' · waiting');timer();$('pass').disabled=!can||s.shopOpen;
 $('money').innerHTML=[0,1].map(c=>'<div class="money"><span>'+side(c)+'<br><small class="muted">'+s.pieces.filter(p=>p.color===c).length+' pieces · '+s.handCount[c]+' cards</small></span><strong>$'+s.money[c]+'</strong></div>').join('');
 $('world').textContent=(s.cards?'Cards awakened. ':'Cards undiscovered. ')+(s.fog?'Fog in the middle two ranks.':s.run?'Campaign battlefield · 8 × 8.':'Expansion on round 20.');
 const board=$('board');board.innerHTML='';board.style.setProperty('--n',s.size);board.className=(s.size===20?'large ':'')+(zoom?'zoom':'');
 const chosen=s.pieces.find(p=>p.id===selected),legal=chosen&&!armed?chosen.legal:[],frag=document.createDocumentFragment();
 for(let row=0;row<s.size;row++)for(let col=0;col<s.size;col++){const x=flipped?s.size-1-col:col,y=flipped?s.size-1-row:row,p=s.pieces.find(p=>p.x===x&&p.y===y),t=s.tiles.find(t=>t.x===x&&t.y===y),h=s.hazards.find(t=>t.x===x&&t.y===y),move=legal.some(m=>m[0]===x&&m[1]===y),b=button('',()=>squareClick(x,y));
 b.className='square'+((x+y)%2?' dark':'')+(p?' has':'')+(p?.id===selected?' sel':'')+(move?' legal'+(p?' capture':''):'')+(h?' '+h.type:'')+(s.fog&&(y===s.size/2||y===s.size/2-1)?' fog':'');
 b.dataset.x=x;b.dataset.y=y;b.setAttribute('role','gridcell');const coord=String.fromCharCode(97+x)+(y+1);b.setAttribute('aria-label',coord+(p?' '+side(p.color)+' '+p.name:' empty')+(move?' available move':''));
 b.innerHTML=(t?'<span class="tile">'+(t.type==='mystery'?'✦':'◕')+'</span>':'')+(p?'<span class="glyph '+(p.color===0?'ivory':'onyx')+'">'+p.icon+'</span>':'')+((row===s.size-1||col===0)?'<span class="coord">'+coord+'</span>':'')+(p&&(p.effects||p.upgrade||p.fusion)?'<span class="badge">'+(p.fusion?'✶':p.upgrade?'↑':p.effects.includes('Frozen')?'❄':'◇')+'</span>':'');
 if(p)b.title=p.name+(p.effects?' · '+p.effects:'');
 b.onkeydown=e=>{const ds={ArrowLeft:[-1,0],ArrowRight:[1,0],ArrowUp:[0,-1],ArrowDown:[0,1]};if(ds[e.key]){e.preventDefault();const d=ds[e.key],nx=x+d[0]*(flipped?-1:1),ny=y+d[1]*(flipped?-1:1);board.querySelector('[data-x="'+nx+'"][data-y="'+ny+'"]')?.focus()}};frag.append(b);
 }board.append(frag);$('size').textContent=s.size+' × '+s.size;$('field').textContent=s.size===8?'THE OPENING FIELD':'THE EXPANSE';$('zoom').hidden=s.size===8;$('zoom').textContent=zoom?'Fit board':'Zoom';
 const inspect=$('selected');inspect.innerHTML=chosen?'<b>'+esc(chosen.name)+'</b><p>'+esc(chosen.effects||'No active effects.')+'</p><p>'+esc(descriptions[chosen.name]||'Select a highlighted square to move.')+'</p>':'Select a piece to inspect its powers.';
 if(chosen&&can&&chosen.color===s.role&&!s.shopOpen){if(chosen.upgrade==='M1 Abrams'||['Iron Warden','Archmage'].includes(chosen.fusion))inspect.append(button('Aim cannon / spell',()=>aim(chosen,'shoot')));if(chosen.fusion==='Archmage'){inspect.append(button('Summon pawn',()=>aim(chosen,'summon')));inspect.append(button('Warp > 5 squares',()=>aim(chosen,'teleport')))}if(chosen.upgrade==='Divine Cleric')inspect.append(button('Revive ally',()=>aim(chosen,'revive')))}
 $('shopBtn').disabled=!can||!s.shop||s.shopOpen;$('shopHint').textContent=!s.shop?'The first mystery tile unlocks the shop.':s.round%5===0?'Market round: one free browsing visit. Purchases end your turn.':'Visiting uses your turn, even without buying.';
 $('hand').innerHTML=s.hand.length?'':'<div class="empty">'+(s.cards?'Draw a new card on your next turn.':'The second mystery tile awakens the card game.')+'</div>';$('count').textContent=s.hand.length+' / '+s.limit;
 s.hand.forEach((d,i)=>{const b=button('',()=>arm('card',i,d),!can||s.shopOpen);b.className='card'+(armed?.kind==='card'&&armed.index===i?' armed':'');b.innerHTML='<b>'+esc(d.name)+'</b><small>'+esc(d.text)+'</small>';$('hand').append(b)});
 $('items').innerHTML=s.items.length?'':'<p class="muted">Find or buy your first relic.</p>';s.items.forEach((d,i)=>{const b=button('',()=>arm('item',i,d),!can||s.shopOpen);b.className='relic'+(armed?.kind==='item'&&armed.index===i?' armed':'');b.innerHTML=esc(d.name)+'<small>'+esc(d.text)+'</small>';$('items').append(b)});
 $('log').innerHTML=s.log.slice(0,15).map(t=>'<p>'+esc(t)+'</p>').join('');
 if(s.shopOpen){shopRender();if(!$('shop').open)$('shop').showModal()}else if($('shop').open)$('shop').close();
}
function shopRender(){
 const s=state;$('shopStatus').textContent='$'+s.money[s.role]+' available. '+(s.shopFree?'Free browsing; purchases end your turn.':'Leaving or buying spends your turn.');document.querySelectorAll('[data-tab]').forEach(b=>b.classList.toggle('active',b.dataset.tab===tab));
 const box=$('shopContent');box.innerHTML='';
 const offer=(title,text)=>{const a=document.createElement('article');a.className='offer';a.innerHTML='<h3>'+esc(title)+'</h3><p>'+esc(text)+'</p>';box.append(a);return a};
 if(tab==='relics'){s.stock.forEach(d=>{const a=offer(d.name,d.text);a.append(button('Buy · $'+d.cost,()=>act({op:'buy',item:d.id}),s.money[s.role]<d.cost))});const a=offer('New stock','Refresh the four relic offers.');a.append(button('Refresh · $25',()=>act({op:'reroll'}),s.money[s.role]<25))}
 const paths={1:['Dragon','Unicorn'],2:['Necromancer','Divine Cleric'],3:['M1 Abrams','Golem']};
 if(tab==='upgrades'){for(const p of s.pieces.filter(p=>p.color===s.role&&paths[p.type]&&!p.upgrade&&!p.fusion)){const a=offer(p.name+' · '+String.fromCharCode(97+p.x)+(p.y+1),'Choose one permanent path.');for(const path of paths[p.type]){const t=document.createElement('p');t.textContent=descriptions[path];a.append(t,button(path+' · $250',()=>act({op:'upgrade',id:p.id,path}),s.money[s.role]<250))}}if(!box.children.length)box.textContent='No eligible unupgraded pieces remain.'}
 if(tab==='fusion')for(const [type,pathsForType]of Object.entries(paths)){const name={1:'Sky Strider',2:'Archmage',3:'Iron Warden'}[type],a=offer(name,descriptions[name]+' Sacrifice '+pathsForType.join(' + ')+'.'),select=document.createElement('select'),y=s.role===0?s.size-1:0;
 for(let x=0;x<s.size;x++)if(!s.pieces.some(p=>p.x===x&&p.y===y)){const o=document.createElement('option');o.value=x;o.textContent='Spawn '+String.fromCharCode(97+x)+(y+1);select.append(o)}
 const eligible=pathsForType.every(path=>s.pieces.some(p=>p.color===s.role&&p.upgrade===path&&!p.fusion));
 select.setAttribute('aria-label','Spawn square');a.append(select,button('Fuse · $500',()=>act({op:'fuse',type,x:select.value,y}),!eligible||!select.children.length||s.money[s.role]<500))}
}
$('pass').onclick=()=>act({op:'pass'});$('shopBtn').onclick=()=>{tab='relics';act({op:'shop'})};$('leave').onclick=()=>act({op:'leave'});$('shop').oncancel=e=>{e.preventDefault();act({op:'leave'})};
document.querySelectorAll('[data-tab]').forEach(b=>b.onclick=()=>{tab=b.dataset.tab;shopRender()});
$('flip').onclick=()=>{flipped=!flipped;render()};$('zoom').onclick=()=>{zoom=!zoom;render()};$('cancel').onclick=()=>{armed=null;notice('Targeting canceled.');render()};
$('rulesBtn').onclick=()=>$('rules').showModal();$('closeRules').onclick=$('play').onclick=()=>$('rules').close();
document.addEventListener('keydown',e=>{if(e.key==='Escape'&&armed){armed=null;render();notice('Targeting canceled.')}});
poll();setInterval(poll,700);
</script></html>
        """;

    static int tests=0;
    static void check(boolean condition,String message){if(!condition)throw new AssertionError(message);}
    static void test(String name,Runnable fn){fn.run();tests++;System.out.println("PASS "+name);}
    static void rejects(Runnable fn){try{fn.run();}catch(IllegalArgumentException expected){return;}throw new AssertionError("Action should have been rejected");}
    static Game emptyGame(){Game g=new Game(1);g.pieces.clear();g.tiles.clear();g.hazards.clear();return g;}
    static void selfTest()throws Exception{
        test("opening: 32 pieces, 20 Ivory moves",()->{Game g=new Game(1);check(g.pieces.size()==32,"piece count");check(g.pieces.stream().filter(p->p.color==0).mapToInt(p->g.moves(p).size()).sum()==20,"move count");});
        test("pawn captures both diagonals; cannot jump blockers",()->{Game g=emptyGame();Piece p=g.add(0,0,3,4);g.add(3,1,2,3);g.add(3,1,4,3);g.add(0,1,3,3);check(g.moves(p).equals(Set.of(new Pos(2,3),new Pos(4,3))),"pawn moves");});
        test("diagonal sliders respect all blockers",()->{Game g=emptyGame();Piece q=g.add(4,0,3,3);for(int[] d:new int[][]{{2,2},{2,4},{4,2},{4,4}})g.add(0,0,d[0],d[1]);check(g.moves(q).stream().allMatch(p->p.x==3||p.y==3),"slider jumps");});
        test("shield blocks capture and consumes attack",()->{Game g=emptyGame();Piece a=g.add(3,0,0,0),b=g.add(0,1,0,3);b.shield=true;g.move(a.id,0,3);check(g.at(0,0)==a&&g.at(0,3)==b&&!b.shield&&g.turn==1,"shield");});
        test("king bounty does not end a surviving army",()->{Game g=emptyGame();Piece a=g.add(3,0,0,0);g.add(5,1,0,3);g.add(0,1,7,1);g.move(a.id,0,3);check(g.players[0].money==700&&g.winner==-1,"king capture");});
        test("last piece capture wins",()->{Game g=emptyGame();Piece a=g.add(3,0,0,0);g.add(5,1,0,3);g.move(a.id,0,3);check(g.winner==0,"winner");rejects(()->g.action(args("op","pass")));});
        test("mystery unlock order",()->{Game g=new Game(1);g.move(g.at(1,6).id,1,5);check(g.shopUnlocked,"shop");g.move(g.at(1,1).id,1,2);check(g.cardsUnlocked&&g.players[0].hand.size()==3,"cards");});
        test("purchase pays exactly once and ends turn",()->{Game g=new Game(1);g.shopUnlocked=true;g.stock=new ArrayList<>(List.of("shield"));g.openShop();g.buy("shield");check(g.players[0].money==100&&g.players[0].items.size()==1&&g.ply==1,"buy");rejects(()->g.buy("shield"));});
        test("market visit free once; repeated visit costs turn",()->{Game g=new Game(1);g.shopUnlocked=true;g.ply=8;g.openShop();g.closeShop();check(g.ply==8,"free visit");g.openShop();g.closeShop();check(g.ply==9,"second visit");});
        test("radio freeze expires after opponent turn",()->{Game g=emptyGame();g.add(5,0,0,7);Piece p=g.add(5,1,7,0);g.players[0].hand.add(new Card("radio",0));g.use(true,0,7,0);g.end();check(g.moves(p).isEmpty(),"not frozen");g.end();g.end();check(!g.moves(p).isEmpty(),"freeze expiry");});
        test("invalid item targeting does not consume it",()->{Game g=new Game(1);g.players[0].items.add("gas");rejects(()->g.use(false,0,0,0));check(g.players[0].items.size()==1&&g.hazards.isEmpty(),"gas consumed");});
        test("promotion and non-promoting spider pawn",()->{Game g=emptyGame();Piece p=g.add(0,0,2,1);g.add(5,1,7,7);g.move(p.id,2,0);check(p.type==4,"promotion");Game h=emptyGame();Piece q=h.add(0,0,2,1);q.noPromote=true;h.add(5,1,7,7);h.move(q.id,2,0);check(q.type==0,"spider pawn promoted");});
        test("round 20 expansion preserves pieces and starting squares",()->{Game g=new Game(1);for(int i=0;i<38;i++)g.end();check(g.size==20&&g.pieces.size()==32&&g.valid(),"expansion");check(g.pieces.stream().allMatch(p->p.x==p.sx&&p.y==p.sy),"home remap");});
        test("fusion needs both paths and sacrifices them",()->{Game g=emptyGame();g.add(1,0,1,5).upgrade="Dragon";g.add(1,0,2,5).upgrade="Unicorn";g.add(5,1,7,0);g.shopUnlocked=true;g.players[0].money=700;g.openShop();g.fuse(1,0,7);check(g.pieces.size()==2&&g.at(0,7).fusion.equals("Sky Strider")&&g.players[0].money==200,"fusion");});
        test("cleric revival charges half base cost",()->{Game g=emptyGame();Piece p=g.add(2,0,3,3);p.upgrade="Divine Cleric";g.add(5,1,7,0);g.graves.add(new Grave(1,0));g.ability(p.id,"revive",4,3,0);check(g.at(4,3).type==1&&g.players[0].money==125&&g.graves.isEmpty(),"revival");});
        test("archmage summons and warps",()->{Game g=emptyGame();Piece p=g.add(2,0,0,0);p.fusion="Archmage";g.add(5,1,7,0);g.ability(p.id,"summon",1,1,-1);check(g.at(1,1).type==0,"summon");g.end();g.ability(p.id,"teleport",6,6,-1);check(p.x==6&&p.y==6,"warp");});
        test("Iron Warden has two shots and blocks movement between them",()->{Game g=emptyGame();Piece p=g.add(3,0,2,2);p.fusion="Iron Warden";g.add(0,1,3,2);g.add(0,1,4,2);g.add(5,1,7,7);g.ability(p.id,"shoot",3,2,-1);check(g.ply==0&&g.shots==1&&g.moves(p).isEmpty(),"first shot");g.ability(p.id,"shoot",4,2,-1);check(g.ply==1&&g.shots==0,"second shot");});
        test("magic shields do not block direct captures",()->{Game g=emptyGame();Piece a=g.add(3,0,0,0);Piece b=g.add(0,1,0,3);b.magic=true;g.move(a.id,0,3);check(g.at(0,3)==a,"magic shield blocked direct attack");});
        test("blanket hides opponent piece type in network state",()->{Session s=new Session(new Game(1),true,0);Piece p=s.g.at(0,6);p.blanket=2;String own=json(s.state(0)),opponent=json(s.state(1));check(own.contains("\"type\":0")&&opponent.contains("\"name\":\"Blanketed piece\""),"blanket");});
        test("timer expires open shop and switches turn",()->{Session s=new Session(new Game(1),true,60);s.g.shopUnlocked=true;s.g.openShop();s.deadline=0;s.tick();check(s.g.turn==1&&!s.g.shopOpen&&s.revision==1,"timer");});
        test("deterministic legal simulations preserve board invariants",()->{for(int seed=1;seed<=8;seed++){Game g=new Game(seed);for(int t=0;t<200&&g.winner==-1;t++){List<int[]> choices=new ArrayList<>();for(Piece p:g.pieces)if(p.color==g.turn)for(Pos m:g.moves(p))choices.add(new int[]{p.id,m.x,m.y});if(choices.isEmpty())g.end();else{int[] m=choices.get((seed*71+t*37)%choices.size());g.move(m[0],m[1],m[2]);}check(g.valid(),"invalid board, seed "+seed+" turn "+t);}}});
        networkTest();
        System.out.println("ALL "+tests+" TESTS PASSED");
    }
    static HttpResponse<String> request(HttpClient client,String base,String path,String token,String body)throws Exception{
        HttpRequest.Builder b=HttpRequest.newBuilder(URI.create(base+path)).timeout(java.time.Duration.ofSeconds(5));
        if(token!=null)b.header("X-Chess-Token",token);
        if(body!=null)b.header("Content-Type","application/x-www-form-urlencoded").POST(HttpRequest.BodyPublishers.ofString(body));
        return client.send(b.build(),HttpResponse.BodyHandlers.ofString());
    }
    static void networkTest()throws Exception{
        try(Session s=new Session(new Game(1),true,0)){
            s.g.players[0].hand.add(new Card("rat",0));s.g.players[1].hand.add(new Card("eject",0));
            s.start("127.0.0.1",0);String base="http://127.0.0.1:"+s.port();HttpClient client=HttpClient.newHttpClient();
            check(request(client,base,"/state",null,null).statusCode()==401,"unauthenticated state");
            check(request(client,base,"/action",null,"op=pass&revision=0").statusCode()==401,"unauthenticated action");
            String white=request(client,base,"/state",s.tokens[0],null).body(),black=request(client,base,"/state",s.tokens[1],null).body();
            check(white.contains("Rat Hat")&&!black.contains("Rat Hat")&&black.contains("Ejector Seat")&&!white.contains("Ejector Seat"),"private hands leaked");
            check(request(client,base,"/action",s.tokens[1],"op=pass&revision=0").statusCode()==409,"wrong turn accepted");
            int pawn=s.g.at(0,6).id;
            check(request(client,base,"/action",s.tokens[0],"op=move&id="+pawn+"&x=0&y=5&revision=0").statusCode()==200,"valid move rejected");
            check(request(client,base,"/action",s.tokens[1],"op=pass&revision=0").statusCode()==409,"stale revision accepted");
            check(request(client,base,"/action",s.tokens[1],"op=pass&revision=1").statusCode()==200,"opponent move rejected");
            check(s.g.ply==2&&s.g.at(0,5).id==pawn,"shared position out of sync");
            check(request(client,base,"/state",s.tokens[0],null).body().equals(request(client,base,"/state",s.tokens[0],null).body()),"reconnect changed state");
            check(request(client,base,"/",null,null).body().contains("CHESS"),"page missing");
            tests++;System.out.println("PASS HTTP two-player auth, private hands, turn ownership, stale revisions and reconnect");
        }
    }
    public static void main(String[] argv)throws Exception{
        Set<String> flags=new HashSet<>(Arrays.asList(argv));
        if(flags.contains("--test")){selfTest();return;}
        boolean host=flags.contains("--host"),serverOnly=flags.contains("--server"),rogue=flags.contains("--roguelike");
        Skill skill=rogue?Skill.NORMAL:null;
        String bind="127.0.0.1";int port=8080,seconds=0;long seed=System.nanoTime();
        for(int i=0;i<argv.length;i++){
            switch(argv[i]){
                case "--bind"->{require(i+1<argv.length,"--bind requires an IP address.");bind=argv[++i];}
                case "--port"->{require(i+1<argv.length,"--port requires a number.");port=Integer.parseInt(argv[++i]);}
                case "--seconds"->{require(i+1<argv.length,"--seconds requires a number.");seconds=Integer.parseInt(argv[++i]);}
                case "--seed"->{require(i+1<argv.length,"--seed requires a number.");seed=Long.parseLong(argv[++i]);}
                case "--bot"->{require(i+1<argv.length,"--bot requires easy, normal, hard or expert.");skill=Skill.parse(argv[++i]);}
                case "--host","--server","--roguelike","--local"->{}
                default->throw new IllegalArgumentException("Unknown option: "+argv[i]);
            }
        }
        require(port>=1&&port<=65535,"Port must be 1–65535.");require(seconds==0||seconds>=10&&seconds<=3600,"Timer must be 0 (off) or 10–3600 seconds.");
        if(argv.length==0&&!GraphicsEnvironment.isHeadless()){
            String[] modes={"Solo vs bot","The Shattered Crown (roguelike)","Local two-player"};
            int choice=JOptionPane.showOptionDialog(null,"Choose how to play","Chess II",JOptionPane.DEFAULT_OPTION,JOptionPane.PLAIN_MESSAGE,null,modes,modes[0]);
            if(choice<0)return;
            if(choice<2){
                Object level=JOptionPane.showInputDialog(null,"Choose bot difficulty","Chess II",JOptionPane.PLAIN_MESSAGE,null,Skill.values(),Skill.NORMAL);
                if(level==null)return;skill=(Skill)level;rogue=choice==1;
            }
        }
        require(!rogue||skill!=null,"Roguelike mode needs a bot.");
        Session s=new Session(new Game(seed),host||serverOnly,seconds,skill,rogue,seed);
        if(host||serverOnly){
            try{s.start(bind,port);}catch(IOException e){System.err.println("Could not host at "+bind+":"+port+". Check that the IP belongs to this PC and the port is unused.");throw e;}
            Runtime.getRuntime().addShutdownHook(new Thread(s::close));
            String address=bind.equals("0.0.0.0")?"YOUR_PC_IP":bind.contains(":")?"["+bind+"]":bind;
            System.out.println("Chess II is running. Keep this terminal open.");
            System.out.println("Ivory invite: http://"+address+":"+port+"/#"+s.tokens[0]);
            if(!s.solo())System.out.println("Onyx invite:  http://"+address+":"+port+"/#"+s.tokens[1]);
            System.out.println(s.solo()?"Onyx is the "+s.skill.name().toLowerCase(Locale.ROOT)+" bot. Open the Ivory invite to play.":"Share only the Onyx invite with your friend. Invite links are private player keys.");
        }
        if(!serverOnly){
            if(GraphicsEnvironment.isHeadless()){s.close();throw new IllegalStateException("No desktop display. Use --server for browser mode.");}
            SwingUtilities.invokeLater(()->new Desktop(s));
        }
    }
}


