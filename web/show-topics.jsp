<%@ page contentType="text/html; charset=utf-8"%>
<%@ page import="java.io.IOException,java.net.URLEncoder,java.sql.*,java.util.Date"   buffer="60kb" %>
<%@ page import="java.util.List"%>
<%@ page import="java.util.Map"%>
<%@ page import="ru.org.linux.boxlet.BoxletVectorRunner"%>
<%@ page import="ru.org.linux.site.*" %>
<%@ page import="ru.org.linux.util.BadImageException" %>
<%@ page import="ru.org.linux.util.HTMLFormatter" %>
<%@ page import="ru.org.linux.util.ImageInfo" %>
<%@ page import="ru.org.linux.util.StringUtil" %>
<%--
  ~ Copyright 1998-2009 Linux.org.ru
  ~    Licensed under the Apache License, Version 2.0 (the "License");
  ~    you may not use this file except in compliance with the License.
  ~    You may obtain a copy of the License at
  ~
  ~        http://www.apache.org/licenses/LICENSE-2.0
  ~
  ~    Unless required by applicable law or agreed to in writing, software
  ~    distributed under the License is distributed on an "AS IS" BASIS,
  ~    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  ~    See the License for the specific language governing permissions and
  ~    limitations under the License.
  --%>

<% Template tmpl = Template.getTemplate(request); %>
<jsp:include page="WEB-INF/jsp/head.jsp"/>

<% String nick=request.getParameter("nick");
	if (nick==null) {
          throw new MissingParameterException("nick");
        }
	
	Connection db = null;
	try {	
	
	  boolean firstPage;
	  int offset;
	  
	  if (request.getParameter("offset") != null) {
		offset = Integer.parseInt(request.getParameter("offset"));
		firstPage = false;
	  } else {
		firstPage = true;
		offset = 0;
	  }

          db = LorDataSource.getConnection();

	  User user = User.getUser(db, nick);
	  
	  Statement st=db.createStatement();
	  ResultSet rs=st.executeQuery("SELECT count(topics.id) FROM topics, users WHERE users.id=topics.userid AND users.id="+user.getId()+" AND NOT deleted");

	  int count = 0;
	  int pages = 0;
	  int topics = tmpl.getProf().getInt("topics");
  
	  if (rs.next()) {
		count = rs.getInt("count");
		pages = count / topics;
		if (count % topics != 0) {
		  count = (pages + 1) * topics;
		}
	  }
	  rs.close();
  
	  if (firstPage || offset >= pages * topics) {
		response.setDateHeader("Expires", System.currentTimeMillis() + 90 * 1000);
	  } else {
		//response.setDateHeader("Expires", new Date(new Date().getTime()-20*3600*1000).getTime());
		response.setDateHeader("Expires", System.currentTimeMillis() + 30 * 24 * 60 * 60 * 1000L);
	  }
	  
	  if (firstPage) {
		out.print("<title>Последние " + topics + " тем пользователя " + nick + "</title>");
	  } else {
		out.print("<title>Последние " + (count - offset) + '-' + (count - offset - topics) + " тем пользователя " + nick + "</title>");		
	  }
%>
<jsp:include page="WEB-INF/jsp/header.jsp"/>
<%
		if (firstPage) {
			out.print("<h1>Последние " + topics + " тем пользователя " + nick + "</h1>");
		} else {
			out.print("<h1>Последние " +(count - offset) + '-' + (count - offset - topics) + " тем пользователя " + nick + "</h1>");
		}
%>
<div class=forum>
<table width="100%" class="message-table">
<thead>
<tr><th>Раздел</th><th>Группа</th><th>Заглавие</th><th>Дата</th><th>Последнее добавление</th></tr>
<tbody>
<%
  if (firstPage) {
	rs=st.executeQuery("SELECT sections.name as ptitle, groups.title as gtitle, topics.title as title, topics.id as msgid, postdate, lastmod FROM topics, groups, sections, users WHERE topics.groupid=groups.id AND sections.id=groups.section AND users.id=topics.userid AND users.id="+user.getId()+" AND NOT deleted ORDER BY msgid DESC LIMIT " + topics);
  } else {
	rs=st.executeQuery("SELECT sections.name as ptitle, groups.title as gtitle, topics.title as title, topics.id as msgid, postdate, lastmod FROM topics, groups, sections, users WHERE topics.groupid=groups.id AND sections.id=groups.section AND users.id=topics.userid AND users.id="+user.getId()+" AND NOT deleted ORDER BY msgid ASC LIMIT " + topics + " OFFSET " + offset);  
  }
  while (rs.next()) {
    out.print("<tr><td>" + rs.getString("ptitle") + "</td><td>" + rs.getString("gtitle") + "</td><td><a href=\"view-message.jsp?msgid=" + rs.getInt("msgid") + "\" rev=contents>" + StringUtil.makeTitle(rs.getString("title")) + "</a></td><td>" + tmpl.dateFormat.format(rs.getTimestamp("postdate")) + "</td><td>" + tmpl.dateFormat.format(rs.getTimestamp("lastmod")) + "</td></tr>");
  }

  rs.close();
  st.close();

%>
</tbody>
<tfoot>
	<tr><td colspan=5><p>
<%
  out.print("<div style=\"float: left\">");

  // НАЗАД
  if (firstPage) {
    out.print("");
  } else if (offset == pages * topics) {
    out.print("<a href=\"show-topics.jsp?nick=" + nick + "\">← первая</a> ");
  } else {
    out.print("<a rel=prev rev=next href=\"show-topics.jsp?nick=" + nick + "&amp;offset=" + (offset + topics) + "\">← назад</a>");
  }

  out.print("</div>");

  // ВПЕРЕД
  out.print("<div style=\"float: right\">");

  if (firstPage) {
    out.print("<a rel=next rev=prev href=\"show-topics.jsp?nick=" + nick + "&amp;offset=" + (pages * topics) + "\">архив →</a>");
  } else if (offset == 0 && !firstPage) {
  } else {
    out.print("<a rel=next rev=prev href=\"show-topics.jsp?nick=" + nick + "&amp;offset=" + (offset - topics) + "\">вперед →</a>");
  }

  out.print("</div>");
%>
	</td></tr>
</tfoot>
</table>
</div>
<div align=center><p>
<%
	for (int i=0; i<=pages+1; i++) {
	  if (firstPage) {
		if (i!=0 && i!=(pages+1) && i>7) {
                  continue;
                }
	  } else {
		if (i!=0 && i!=(pages+1) && Math.abs((pages+1-i)*topics-offset)>7*topics) {
                  continue;
                }
	  }
	  
	  if (i==pages+1) {
		if (offset!=0 || firstPage) {
                  out.print("[<a href=\"show-topics.jsp?nick=" + nick + "&amp;offset=0\">последняя</a>] ");
                } else {
                  out.print("[<b>последняя</b>] ");
                }
	  } else if (i==0) {
		if (firstPage) {
                  out.print("[<b>первая</b>] ");
                } else {
                  out.print("[<a href=\"show-topics.jsp?nick=" + nick + "\">первая</a>] ");
                }
	  } else if ((pages+1-i)*topics==offset) {
		out.print("<b>"+(pages+1-i)+"</b> ");
	  } else {
		out.print("<a href=\"show-topics.jsp?nick="+nick+"&amp;offset="+((pages+1-i)*topics)+"\">"+(pages+1-i)+"</a> ");
	  }
	}
%>
  </div>
  <%
  } finally {
    if (db!=null) {
      db.close();
    }
  }
%>
<jsp:include page="WEB-INF/jsp/footer.jsp"/>
