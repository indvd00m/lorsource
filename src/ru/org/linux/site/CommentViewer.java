/*
 * Copyright 1998-2009 Linux.org.ru
 *    Licensed under the Apache License, Version 2.0 (the "License");
 *    you may not use this file except in compliance with the License.
 *    You may obtain a copy of the License at
 *
 *        http://www.apache.org/licenses/LICENSE-2.0
 *
 *    Unless required by applicable law or agreed to in writing, software
 *    distributed under the License is distributed on an "AS IS" BASIS,
 *    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *    See the License for the specific language governing permissions and
 *    limitations under the License.
 */

package ru.org.linux.site;

import java.io.IOException;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import java.util.ListIterator;
import java.util.Set;
import java.util.logging.Logger;

import ru.org.linux.util.UtilException;

public class CommentViewer {
  private static final Logger logger = Logger.getLogger("ru.org.linux");

  public static final int COMMENTS_INITIAL_BUFSIZE = 50;

  public static final int FILTER_NONE = 0;
  public static final int FILTER_ANONYMOUS = 1;
  public static final int FILTER_IGNORED = 2;

  private final Template tmpl;
  private final CommentList comments;
  private final boolean expired;
  private final Connection db;

  private final String user;
  public static final int FILTER_LISTANON = FILTER_ANONYMOUS+FILTER_IGNORED;

  private int outputCount = 0;

  public CommentViewer(Template t, Connection db, CommentList comments, String user, boolean expired) {
    tmpl=t;
    this.comments = comments;
    this.user=user;
    this.expired = expired;
    this.db = db;
  }

  private void showCommentList(StringBuffer buf, List<Comment> comments, boolean reverse, int offset, int limit, Set<Integer> hideSet)
      throws IOException, UtilException, SQLException, UserNotFoundException {
    CommentView view = new CommentView();
    int shown = 0;

    for (ListIterator<Comment> i = comments.listIterator(reverse?comments.size():0); reverse?i.hasPrevious():i.hasNext();) {
      int index = reverse?(comments.size()-i.previousIndex()):i.nextIndex();

      Comment comment = reverse?i.previous():i.next();

      if (index<offset || (limit!=0 && index>=offset+limit)) {
        continue;
      }

      if (hideSet==null || !hideSet.contains(comment.getMessageId())) {
        shown++;
        outputCount++;
        buf.append(view.printMessage(comment, tmpl, db, this.comments, true, tmpl.isModeratorSession(), user, expired));
      }
    }

    logger.fine("Showing list size="+comments.size()+" shown="+shown);    
  }

  public String show(boolean reverse, int offset, int limit, Set<Integer> hideSet) throws IOException, UtilException, SQLException, UserNotFoundException {
    StringBuffer buf=new StringBuffer();

    showCommentList(buf, comments.getList(), reverse, offset, limit,  hideSet);

    return buf.toString();
  }

  public String showSubtree(int parentId) throws IOException, UtilException, MessageNotFoundException, SQLException, UserNotFoundException {
    StringBuffer buf=new StringBuffer();

    CommentNode parentNode = comments.getNode(parentId);

    if (parentNode==null) {
      throw new MessageNotFoundException(parentId);
    }

    List<Comment> parentList = new ArrayList<Comment>();
    parentNode.buildList(parentList);

    /* display comments */
    showCommentList(buf, parentList, false, 0, 0, null);

    return buf.toString();
  }

  public static int parseFilterChain(String filter) {
    if ("list".equals(filter)) {
      return FILTER_IGNORED;
    }

    if ("anonymous".equals(filter)) {
      return FILTER_ANONYMOUS;
    }

    if ("listanon".equals(filter)) {
      return FILTER_IGNORED+FILTER_ANONYMOUS;
    }

    return FILTER_NONE;
  }

  public static String toString(int filterMode) {
    switch (filterMode) {
      case FILTER_NONE: return "show";
      case FILTER_ANONYMOUS: return "anonymous";
      case FILTER_IGNORED: return "list";
      case FILTER_IGNORED+FILTER_ANONYMOUS: return "listanon";
      default: return "show";
    }
  }

  public int getOutputCount() {
    return outputCount;
  }
}
